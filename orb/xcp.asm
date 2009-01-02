;========================================================================================
;
; Exception handling
;
;========================================================================================

GLOBAL method_fault
GLOBAL build_xcp_imgs
GLOBAL make_orb_xcp
GLOBAL throw_fatal_xcp
GLOBAL throw_invalid_xcp
GLOBAL throw_gp_xcp
GLOBAL throw_rsc_xcp
GLOBAL throw_nomem_xcp
GLOBAL throw_noref_xcp

EXTERN method_call.ds_fault
EXTERN method_call.cs_fault
EXTERN method_call.ref2big
EXTERN method_xfer.ds_fault
EXTERN method_fcall.ds_fault
EXTERN method_fcall.stack_fault
EXTERN method_ret.normal_ds_fault
EXTERN method_ret.fcall_ret
EXTERN method_create.ctor_cs_fault
EXTERN method_create.ctor_ds_fault
EXTERN method_destroy.dtor_cs_fault
EXTERN method_destroy.dtor_ds_fault

EXTERN desc.get_base
EXTERN desc.get_limit


%define __COMPILE_XCP
%define ___COMPILE_ORB_CONSOLE
%include "orb.inc"
%include "orb_link.inc"
%include "cdt.inc"
%include "type.inc"
%include "stack.inc"
%include "mt.inc"
%include "version"
%include "Console.inc"
%include "debug.inc"


section .text
bits 32

;================================ BUILD_XCP_IMGS ========================================
;
; Install ORB exception types from hardcoded image
;
; ECX = from (start sel)
; EBX = to   (end sel)
;
; HIGH_TEMPLATE is set of constant bits for exception image descriptors
HIGH_TEMPLATE equ 0x00409200

build_xcp_imgs:
   push     edx
   push     esi
   push     edi
   xor      edi, edi
   mov      esi, xcp_orb_rsc_end - xcp_orb_rsc_img - 1     ; esi = xcp type segment limit

.loop_start:
   mov     eax, xcp_imgs
   add     eax, [ orb_linear ]                             ;linear address of our xcp imgs in EAX
   add     eax, edi                                        ;current xcp img

   ; -- Build descriptor

   lea   edx, [ orb_gdt + ecx ]                            ; load descriptor ptr
   mov   word  [ edx ], si                                 ;set descriptor's limit
   mov   [ edx + 2 ], ax                                   ;put low word of base into descr
   mov   dword [ edx + 4 ], HIGH_TEMPLATE                  ;mark top of descr with invariant bits
   shr   eax, 16                                           ;get base[16..31]
   mov   [ edx + 4 ], al                                   ;put base[16..23] into descr
   mov   [ edx + 7 ], ah                                   ;put base[24..31] into descr

   ; -- Build CDT entry

   mov   eax, ecx                                          ;take copy of current selector in eax
   shl   eax, 2                                            ;convert from a selector to an objref
   add   eax, orb_cdt                                      ; load cdt ptr
   xor   edx, edx
   mov   [ eax + CDT.ds_sel ], cx                          ; set selector
   mov   word  [ eax + CDT.cs_sel ], dx                    ;null type has no CS
   mov   dword [ eax + CDT.type_ptr ], TYPE_PTR_DATA       ;null type
   mov   dword [ eax + CDT.gdt_lock ], edx                 ;zero GDT lock
   mov   dword [ eax + CDT.mcount ], edx                   ;null types have no methods
   mov   dword [ eax + CDT.call_count ], edx               ;zero call count
   mov   dword [ eax + CDT.mtbl ], edx                     ;no method table
   mov   edx,  [ orb_gdt + ecx ]                           ;get bottom dword of descr into edx and...
   mov   [ eax + CDT.descr1 ], edx                         ;...place it in CDT descr bottom
   mov   edx,  [ orb_gdt + ecx + 4 ]                       ;get top dword of descr into edx and...
   mov   [ eax + CDT.descr2 ], edx                         ;...place it in CDT descr top

   push  ebx                                               ; preserve last selector
   mov   eax, ecx                                          ; get current selector
   shr   eax, 3                                            ;convert selector to a reference (/8)
   mov   ebx, eax                                          ;gonna install the ref in EBX
   shl   eax, 2                                            ;turn into rev_tbl index         (*4)
   mov   dword [ rev_tbl + eax ], ebx
   push  dword [ current_comp ]
   mov   dword [ current_comp ], 0
   METHOD_INSTALL                                          ;well, install it then!
   pop   dword [ current_comp ]
   pop   ebx                                               ; restore last selector

   add   edi, esi                                          ;add ( sizeof( img_desc ) - 1 ) to edx
   inc   edi                                               ;inc so we've effectively added sizeof( img_desc )
   add   ecx, 8                                            ;move to next selector
   cmp   ecx, ebx
   jle   .loop_start

   pop      edi
   pop      esi
   pop      edx
   ret


;==================================== MAKE_ORB_XCP ======================================
;
; {ref, addr} make_orb_xcp( objref type )
;
;   Makes an exception and returns the reference in EAX and
;   the address of its datum relative to ORB's DS in EDX.
;
make_orb_xcp:
.try_grab_xcp:                                ;grab 4 bytes for the exception from the xcp_fl
   mov      eax, [ xcp_fl ]
   test     eax, eax
   jz       short .nomem
   mov      edx, [ eax ]
   cmpxchg  [ xcp_fl ], edx
   jne      .try_grab_xcp

   mov      edx, eax             ;store the datum address relative to ORB's DS in EDX, ready for the return
   add      eax, [ orb_linear ]          ;add the ORB's linear base to convert from offset within ORB's DS to linear address

   push  dword [ current_comp ]
   mov   dword [ current_comp ], 0
   push  dword 0                 ; pass no parameters to constructor
   push  eax                     ; where
   push  dword [ esp + 16 ]      ; what (i.e. the 'type' parameter -- [esp]==where; [esp+4]==param_count; [esp+8]==current_comp; [esp+12]==ret_addr; [esp+16]==type param)
   mov   eax, 1                  ; we're only creating one component.
   METHOD_CREATE                 ; create the exception (ref to exception now in eax)
   add   esp, 12
   pop   dword [ current_comp ]

   ret

.nomem:
   push  dword [ current_comp ]
   push  dword ORB.XCP_SIZE                                ; need space for an orb exception.
   push  dword -1                                          ; dunno the return-to address.
   call  throw_nomem_xcp                                   ; throw an exception to get it.
   add   esp, 8                                            ; when control gets here, the
   pop   dword [ current_comp ]                            ; exception has been dealt with.
   jmp   .try_grab_xcp                                     ; let's try again...


;====================================== XCP HANDLING ====================================

   ; -- throw_gp_xcp( objref type, uint datum );
   ;  Throw a general purpose exception.  The faulting condition
   ;  can be retried by the exception handler issuing an iret

throw_gp_xcp:
   push     dword [ esp + 4 ]
   call     make_orb_xcp
   add      esp, 4
   mov      ebx, [ esp + 8 ]                               ;get the datum -- [esp]==ret_addr; [esp+4]==type; [esp+8]==datum
   mov      [ edx ], ebx                                   ;place it in the space for the exception
   mov      ebx, [ current_comp ]                          ;return-to component is our caller
   pop      ecx                                            ;return-to address in ecx
   add      esp, 4                                         ;'pop' the code segment to return to.
   int      ORB.XCP_INT_VEC                                ;and trigger interrupt indicating exception
   ret

throw_noref_xcp:
   push     ebx
   push     dword ORB.XCP_NOREF_TYPE
   jmp      throw_gp_xcp

   ; -- Code to marshall up exceptions to be thrown to the caller

throw_rsc_xcp:
   add      esp, 4                                         ;step over create's local variable
   pop      ebp                                            ;restore ebp
   add      esp, 4                                         ;step over caller' ds
   mov      eax, ORB.XCP_RSC_COMP                          ;passing the resources exhausted exception
   mov      ebx, [ current_comp ]                          ;return-to component is our caller
   pop      ecx                                            ;return-to address in ecx
   int      ORB.XCP_INT_VEC                                ;and trigger interrupt indicating exception

   ; -- throw_nomem( uint trigger_eip, uint amount_required )

throw_nomem_xcp:
   mov      eax, [ active_stack ]
   mov      ebx, [ eax + STACK_EL.nomem_xcp_ptr ]          ;get the address of the nomem exception datum (relative to ORB DS)
   mov      ecx, [ esp + 8 ]                               ;get the amount of memory required
   mov      [ ebx ], ecx                                   ;place it in the nomem exception's datum
   mov      eax, [ eax + STACK_EL.nomem_xcp_ref ]          ;find the nomem exception's ObjRef
   mov      ebx, [ current_comp ]                          ;get the trigger ObjRef
   mov      ecx, [ esp + 4 ]                               ;get the trigger EIP
   int      ORB.XCP_INT_VEC                                ;and trigger the exception
   ret                                                     ;when we come back, let's retry the operation

   ; -- throw_fatal_xcp
   ; unlike throw_gp_xcp, exceptions via here cannot be retried.

throw_fatal_xcp:
   mov      eax, ORB.DYNAMIC_SEL                           ;First off, might have been called from ORB's static DS -- switch to dynamic one
   mov      ds, eax

   push     edx                                            ;now make an exception -- save away the special ingo
   push     ecx                                            ;push the type as a parameter to make_orb_xcp
   call     make_orb_xcp                                   ;call it
   add      esp, 4
   pop      dword [ edx ]                                  ;restore the datum into the address the exception is at
   mov      ebx, [ current_comp ]                          ;return-to component is our caller
   pop      ecx                                            ;return-to address in ecx
   add      esp, 4                                         ;'pop' the code segment to return to.
   int      ORB.XCP_INT_VEC                                ;and trigger interrupt indicating exception

   ; -- OK, throw an xcp_orb_invalid exception.  First create an
   ; instance of said exception and then throw via XCP_INT_VEC
   ; Note that we have to get space for the xcp from the xcp_fl

throw_invalid_xcp:
   mov      ecx, ORB.XCP_INVALID_TYPE
   jmp      throw_fatal_xcp


;================================== FAULT ===============================================
; method_fault
; note that fault_ds_patch is above method_fault to help the branch prediction
;
fault_cs_patch:
   mov      ebx, [ esp + 32 ]                              ;get ebx that was pushed by our caller
   mov      eax, ORB.STATIC_SEL
   lsl      eax, eax
   add      ebx, orb_cdt
   cmp      ebx, eax                                       ;compare ebx pointer to end of static segment
   jge      not_quick_fault                                ;if ebx ptr is bigger, then ebx was an invalid reference
   mov      ebx, [ ebx + CDT.type_ptr ]                    ;now find the type (i.e. CS)
   cmp      word [ ebx + CDT.ds_sel ], 0xFFFE
   jne      not_quick_fault

   ; -- We've determined that it really can be fixed by selector replacement,
   ; so grab a selector and patch CDT

   sub      ebx, orb_cdt                                   ;type stored as pointer into CDT; convert back to reference
   shr      ebx, 5
   push     ebx                                            ;push the faulting reference
   call     load_gdt                                       ;and reload it into the GDT
   add      esp, 4                                         ;restore stack

   ; -- Now we also need to patch the method table

   shl      ebx, 5
   mov      ebx, [ orb_cdt + ebx + CDT.mtbl ]              ;get the method table's address
   mov      ecx, [ ebx + MT.mcount ]                       ;get number of normal methods on this type
   add      ecx, 2                                         ;account for ctor and dtor which need patching too
.patch_method:
   mov      word [ ebx + MT.ctor + ecx * 8 + 4 ], ax       ;patch method
   dec      ecx                                            ;next method
   jns      .patch_method                                  ;Did the decr wrap around?  If so, we've patched everything, otherwise patch more

   ; -- All done; let's get out of here

   pop      ds                                             ;restore context...
   retf                                                    ;...and return to caller.

   ; ===== FIXME: this thing needs through fixing.... =====

find_faulting_ref:
   mov      ebx, [ esp + 40 ]             ;get ebx that was pushed by our caller
   mov      eax, ORB.STATIC_SEL
   lsl      eax, eax
   add      ebx, orb_cdt
   cmp      ebx, eax
   jge      short .quick_fault_failed
   sub      ebx, orb_cdt
   cmp      word [ orb_cdt + ebx + CDT.ds_sel ], CDT.SEL_TYPE_UNCACHED
   jne      short .check_zombie
   shr      ebx, 5
   ret

.check_zombie:
   cmp      word  [ orb_cdt + ebx + CDT.ds_sel ], CDT.SEL_TYPE_ZOMBIE
   jne      .quick_fault_failed

   ; so it looks like an attempt has been made to return into a zombie.
   ; we need to iret straight into exception 0x40??

;fixme_halting
   int      48
   ;push dword 0x2222
   ;push dword XCP_ORB_TYPE
.quick_fault_failed:
   add      esp, 4                     ;pop return address from call to us
   jmp      not_quick_fault                  ;'return' to not_quick fault


; FIXME: We need to be careful about when a component
; faults in its constructor or destructor.  The library OS
; should check the type of faulting components,
; if it's a zombie or free then the libOS needs to call
; into the ORB to have it clear up.... ouch!

fault_ds_patch:
   call     find_faulting_ref                              ;convert it into an ObjRef
   push     ebx
   call     load_gdt                                       ;cache that objref into the GDT
   add      esp, 4
   pop      ds                                             ;restore our context
   retf                                                    ;and return


;============================================= FAULT ====================================
;
; input:
;  [esp+00] DS            saved DS
;  [esp+04] sel          \ return-to component
;  [esp+08] offs         /
;  [esp+12] SS
;  [esp+16] DS            fault DS (either ORB.STATIC_SEL or ORB.DYNAMIC_SEL)
;  [esp+20] EDI       \
;  [esp+24] ESI        |
;  [esp+28] EBP        |
;  [esp+32] ESP         \ gp_regs
;  [esp+36] EBX         / 32 bytes
;  [esp+40] EDX        |
;  [esp+44] ECX        |
;  [esp+48] EAX       /
;  [esp+52] error_code    put on stack by processor upon fault
;  [esp+56] EIP           \
;  [esp+60] CS             > return-to faulting address
;  [esp+64] EFLAGS        /
;
method_fault:
   push     ds
   mov      eax, ORB.DYNAMIC_SEL
   mov      ds, eax

   ; -- Can we deal with the fault quickly?

   mov      eax, [ esp + 56 ]
   cmp      eax, method_xfer.ds_fault
   je       fault_ds_patch
   cmp      eax, method_fcall.ds_fault
   je       fault_ds_patch
   cmp      eax, method_call.ds_fault
   je       fault_ds_patch
   cmp      eax, method_create.ctor_ds_fault
   je       fault_ds_patch
   cmp      eax, method_destroy.dtor_ds_fault
   je       fault_ds_patch
   cmp      eax, method_ret.normal_ds_fault
   je       fault_ds_patch

   cmp      eax, method_call.cs_fault
   je       fault_cs_patch
   cmp      eax, method_create.ctor_cs_fault
   je       fault_cs_patch
   cmp      eax, method_destroy.dtor_cs_fault
   je       fault_cs_patch

not_quick_fault:

   ; -- not a DS patch

   cmp eax, method_ret.fcall_ret
   jne short .next_fault1

   ; -- return from fcall faulted

   mov esi, fcall_ret_fault
   call console__print
   cli
   jmp short $


.next_fault1:
   cmp eax, method_call.ref2big
   jne short .next_fault2

   ; -- called on too big objref

   mov ebx, [ esp + 36 ]
   shr ebx, 5

   mov esi, too_big_ref
   call console__print
   mov edx, ebx
   call console__print_dword
   mov esi, which_is_at
   call console__print
   shl ebx, 5
   add ebx, orb_cdt
   mov edx, ebx
   call console__print_dword

   mov esi, orb_gdt
   mov eax, ORB.STATIC_SEL
   call desc.get_base
   call desc.get_limit

   mov esi, the_static_desc
   call console__print
   mov edx, ebx
   call console__print_dword
   mov esi, static_limit
   call console__print
   mov edx, ecx
   call console__print_dword

   cli
   jmp short $


.next_fault2:
   cmp eax, method_fcall.stack_fault
   jne .next_fault3

   ; -- get stack chain element

   mov eax, [ esp + 40 ]
   cmp word [ eax + STACK_EL.next_ss ], CDT.SEL_TYPE_UNCACHED
   jne .next_stack_fault

   mov esi, fcall_stack_fault
   call console__print
   mov edx, [ eax + STACK_EL.this_ref ]
   call console__print_dword
   mov esi, right_arrow
   call console__print
   mov edx, [ eax + STACK_EL.next_ref ]
   call console__print_dword
   mov esi, next_ss_is
   call console__print
   mov edx, [ eax + STACK_EL.next_ss ]
   call console__print_dword
   mov esi, reloading
   call console__print

   mov edx, [ eax + STACK_EL.next_ref ]
   shl edx, 5
   lea esi, [ orb_cdt + edx + CDT.descr ]
   xor eax, eax
   call desc.get_base
   call desc.get_limit

   mov edx, ebx
   call console__print_dword
   mov al, '/'
   call console__print_char
   mov edx, ecx
   call console__print_dword

   mov edx, [ esp + 40 ]
   push dword [ edx + STACK_EL.next_ref ]
   call load_gdt                                           ; bring descriptor to GDT
   add esp, 4
   mov dword [ edx + STACK_EL.next_ss ], eax               ; write selector in its place

   mov esi, done_ss
   call console__print
   mov eax, edx
   mov edx, [ eax + STACK_EL.next_ss ]
   call console__print_dword
   mov esi, this_ss
   call console__print
   mov edx, [ eax + STACK_EL.this_ref ]
   shl edx, 5
   movzx edx, word [ orb_cdt + edx + CDT.ds_sel ]
   call console__print_dword
   call console__newline

   pop      ds
   retf


.next_stack_fault:
   mov eax, [ esp + 40 ]
   cmp word [ eax + STACK_EL.next_ss ], STACK_EL.END_OF_CHAIN
   jne .next_stack_fault2

   mov esi, fcall_at_end
   call console__print

   cli                                                     ; FIXME: Throw exception
   jmp short $


.next_stack_fault2:
   mov esi, fcall_fault
   call console__print
   mov eax, [ esp + 40 ]
   mov edx, [ eax + STACK_EL.next_ss ]
   call console__print_dword
   mov al, ':'
   call console__print_char
   mov edx, [ eax + STACK_EL.next_esp ]
   call console__print_dword

   ; -- if control gets here we have some different problem... fault as normal.

.next_fault3:
   mov esi, orb_fault
   call console__print
   mov edx, [ esp + 8 ]
   call console__print_dword
   mov esi, with_eflags
   call console__print
   mov edx, [ esp + 64 ]
   call console__print_dword

   mov esi, orb_cdt_sel
   call console__print
   mov edx, [ esp + 36 ]
   movzx edx, word [ orb_cdt + edx + CDT.ds_sel ]
   call console__print_word

   mov esi, r_eax
   call console__print
   mov edx, [ esp + 48 ]
   call console__print_dword

   mov esi, r_ebx
   call console__print
   mov edx, [ esp + 36 ]
   call console__print_dword

   mov esi, r_ecx
   call console__print
   mov edx, [ esp + 44 ]
   call console__print_dword

   mov esi, r_edx
   call console__print
   mov edx, [ esp + 40 ]
   call console__print_dword

   mov esi, r_esi
   call console__print
   mov edx, [ esp + 24 ]
   call console__print_dword

   mov esi, r_edi
   call console__print
   mov edx, [ esp + 20 ]
   call console__print_dword

   mov esi, r_ebp
   call console__print
   mov edx, [ esp + 28 ]
   call console__print_dword

   mov esi, r_esp
   call console__print
   mov edx, [ esp + 32 ]
   call console__print_dword

   call console__newline

   mov esi, r_ds
   call console__print
   mov edx, [ esp + 16 ]
   call console__print_dword

   mov esi, r_ss
   call console__print
   mov edx, [ esp + 12 ]
   call console__print_dword

   call console__newline

   ; -- dump stack

   mov eax, ss
   lsl eax, eax
   sub eax, 31                                             ; 8*4 words -1 for limit
   add esp, 68                                             ; get everything off stack
   cmp eax, esp                                            ; is EAX < ESP ?
   jb  short .no_stackdump                                 ; yes, we're short on stack

   call console__debug_showstack

.no_stackdump:
   cli
   jmp short $


section .data

fcall_ret_fault:    db "[ORBFAULT] f-call ret fault!!!",0
too_big_ref:        db "[ORBFAULT] Too big a reference used on call. Used ref ",0
which_is_at:        db " at ",0
the_static_desc:    db EOL,"[ORBFAULT] The static descriptor has base ",0
static_limit:       db ", limit ",0
fcall_stack_fault:  db "[ORBFAULT] f-call stack fault on stack ",0
right_arrow:        db " -> ",0
next_ss_is:         db EOL,"[ORBFAULT] Next SS is ",0
reloading:          db " -- reloading: ",0
done_ss:            db EOL,"[ORBFAULT] done; stack->next_ss is now: ",0
this_ss:            db "; stack->ss is ",0
fcall_at_end:       db "[ORBFAULT] f-call attempted at end of stack chain!",0
fcall_fault:        db "[ORBFAULT] f-call fault when trying to lss ",0
orb_fault:          db EOL,"[ORBFAULT] ORB fault at unknown origin! Happened at ",0
with_eflags:        db " with eflags: ",0
orb_cdt_sel:        db EOL,"[ORBFAULT] orb_cdt[ebx].sel=",0
r_eax:              db EOL, '[ORBFAULT] eax: ', 0
r_ebx:              db     ' ebx: ', 0
r_ecx:              db     ' ecx: ', 0
r_edx:              db     ' edx: ', 0
r_esi:              db EOL, '[ORBFAULT] esi: ', 0
r_edi:              db     ' edi: ', 0
r_ebp:              db     ' ebp: ', 0
r_esp:              db     ' esp: ', 0
r_ds:               db EOL, '[ORBFAULT] ds: ',0
r_ss:               db     ' ss: ',0

;
; Hardcoded exception objects
;
%macro xcp_image 1
align 4
xcp_orb_%1_img:
.sect_text:
.method_get_data:
   mov      eax, [ 0 ]
.method_ctor:
.method_dtor:
   METHOD_RET
.text_end:
.sect_data:
.data_end:
.sect_bss:
.bss_end:
.sect_mt:
   dd    1                                                 ;method count is 1
   dd    0                                                 ;pad to align
   dd    .method_ctor - .sect_text                         ;ctor offset
   dd    0                                                 ;gap for CS
   dd    .method_dtor - .sect_text                         ;dtor offset
   dd    0                                                 ;gap for CS
   dd    .method_get_data - .sect_text                     ;the one method's entry point
   dd    0                                                 ;gap for CS
.mt_end:
.sect_descr:
.txt_st: dd     .sect_text - xcp_orb_%1_img
.txt_sz: dd     .text_end - .sect_text
.dat_st: dd     .sect_data - xcp_orb_%1_img
.dat_sz: dd     .data_end - .sect_data
.bss_st: dd     .sect_bss - xcp_orb_%1_img
.bss_sz: dd     4                                          ;the datum that info() returns
.mt_st:  dd     .sect_mt - xcp_orb_%1_img
.mt_sz:  dd     .mt_end - .sect_mt
.version: dd    __odin_VERSION
xcp_orb_%1_end:
%endmacro


;=============================================================================================
align 4

xcp_imgs:
xcp_image rsc
xcp_image invalid
xcp_image noref
xcp_image nomem
xcp_image nostack
xcp_image noret
xcp_image zombie

;=============================================================================================
