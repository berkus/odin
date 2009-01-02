;========================================================================================
;
; The ORB implementation
;
; Instance creation
;
;========================================================================================

GLOBAL method_create

; for method_set_type
GLOBAL method_create.create_loop
GLOBAL grab_multi_refs
GLOBAL grab_ref

; for exception handling
GLOBAL method_create.ctor_cs_fault
GLOBAL method_create.ctor_ds_fault

EXTERN make_orb_xcp  ; xcp.asm


%include "orb.inc"
%include "cdt.inc"
%include "stack.inc"
%include "orb_link.inc"
%include "type.inc"
%include "desc.inc"
%include "mt.inc"

%define ___COMPILE_ORB_CONSOLE
%include "Console.inc"
%include "debug.inc"


FL_GROW_DELTA  equ 256


section .data
first_stack: dd 1


section .text
bits 32



;/*-----------------------.
;|  create                |
;|------------------------'-------------------------------------------------------------.
;| objref create( eax=count, objref type, uint where, uint param_count, ... );          |
;|                                                                                      |
;| Description:                                                                         |
;| Create count components with contiguous object references.  There are 'count'        |
;| {type, where, param_list} triples on the stack, where 'type' is the objref of        |
;| the type to create an instance of, 'where' is the linear address of the instance's   |
;| DS, and 'param_count' is the number of bytes of paramters to pass to the constructor.|
;| FIXME: throw nomem exception if bottom of component would overlap top of CDT         |
;|                                                                                      |
;| Input:                                                                               |
;|    EAX = count                                                                       |
;|    the rest is on the stack                                                          |
;| Output:                                                                              |
;|    count components created                                                          |
;`-------------------------------------------------------------------------------------*/
ALIGN 16
method_create:
   test     eax, eax                                       ;Only bother creating anything if EAX is not zero!
   jz       .exit

   ; -- Switch to the ORB's context

   pushad
   mov      edx, ORB.DYNAMIC_SEL
   mov      ds, edx
   push     eax                                            ;store away the total number of ObjRefs we've been asked to create [16]
   lea      ebp, [ esp + 44 ]                              ;[esp] = 'how many'; [esp+4] = regs, [esp+36] = caller EIP,
                                                           ;[ esp + 40 ] = caller CS, [ esp + 44 ] = first type,
                                                           ;[ebp] = what, [ ebp + 4 ] = where, [ ebp + 8 ] = param_count
%ifdef _DEBUG
   xor      edx, edx
   cmp      eax, ORB.MAX_FL_NUMBER
   jg       .throw0
;   inc      edx
;   test     eax, eax ; this test is crap, never reached (EAX==0 rejected on enter)
;   jz near  .throw0
   cmp      esp, 128
   jl       throw_rsc_xcp
%endif

   ; -- Find the appropriate ObjRef free-list to put stuff on

   push     eax                                            ;put the 'ObjRef count' parameter on the stack (but leave it there)
   call     grab_multi_refs                                ;create the ObjRefs.
                                                           ;Note: we deliberately leave the ObjRef count on the stack [14]

   ; -- ObjRefs are allocated - now have to fill in each CDT entry
   ; first of all we have to create the descriptor

.create_loop:
   push     eax                                            ;put the ObjRef just created on the stack so we can clobber EAX [15]
   mov      ecx, [ ebp ]                                   ;get the type into ECX
   cmp      ecx, TYPE_REF_STACK
   jle      .get_base_type_sz

   xor      eax, eax                                       ;size is going in EAX
   shl      ecx, 5                                         ;ok, type is in ECX, so get ready to index CDT
   mov      ebx, [ orb_cdt + ecx + CDT.init_ref ]          ;find out init data ref
   test     ebx, ebx                                       ;is there any initial data?
   jz       short .get_bss_sz                              ;if there's no init data, we take the size from BSS

   push  dword [ current_comp ]
   mov   dword [ current_comp ], 0
   METHOD_LOCK                                             ;lock init DS in GDT and get selector in EAX [20]
   pop   dword [ current_comp ]

   lsl      eax, eax                                       ;use the chip to get limit into EAX
   inc      eax

.get_bss_sz:
   add      eax, [ orb_cdt + ecx + CDT.bss_sz ]
   jmp      short .got_sz

.get_base_type_sz:
   mov      eax, [ ebp + 12 ]                              ;base types have their size as the first constructor parameter

.got_sz:

   ; -- Build the descriptor.  EAX is sz, EBX is type, ECX is start, EDX DESC1, EDI DESC2

   mov      ebx, [ ebp ]                                   ;get type into EBX  (FIXME: it's already in ECX -- clean up this instr )  -- actually we can prbably remove this complete!
   mov      ecx, [ ebp + 4 ]                               ;get base into ECX
   cmp      eax, 0x100000                                  ;is the size > 1Meg?
   jle      short .byte_gran
   add      eax, 4095
   shr      eax, 12                                        ;round up to page granularity
   mov      edi, DESC.PAGE_GRAN | DESC.DEFAULT_DATA
   jmp      short .page_gran
.byte_gran:
   mov      edi, DESC.BYTE_GRAN | DESC.DEFAULT_DATA
.page_gran:
   dec      eax                                            ;convert size to limit
   mov      edx, eax                                       ;get size
   mov      esi, ecx                                       ;copy base
   shl      esi, 16                                        ;shift it to get base 0..15
   and      edx, 0xFFFF                                    ;clear rubbish at top of edx
   or       edx, esi                                       ;built DESC1 in EDX

   mov      esi, ecx                                       ;get copy of base
   and      esi, 0x00FF0000                                ;get base 16..23
   shr      esi, 16                                        ;shift base 16..23 so its right for DESC2
   and      eax, 0x000F0000                                ;calc DESC2's limit 16..19
   and      ecx, 0xFF000000                                ;calc DESC2's base  24..31 and 16..23
   or       ecx, eax                                       ;or together to get base and limit fields
   or       edi, ecx                                       ;or it in with the other shite
   or       edi, esi                                       ;or it in with base 16..23 -- built DESC2 in EDI

   pop      eax                                            ;get ObjRef back from stack [15]
   shl      eax, 5
   mov      [ orb_cdt + eax + CDT.descr1 ], edx
   mov      [ orb_cdt + eax + CDT.descr2 ], edi
   shr      eax, 5

   ; -- We have the reference range (starting from EAX): let's do the creation
   ; First check to see if we're creating an instance of a `base type'
   ; [ebp] = 'what', [ebp+4] = 'where', EAX = current reference

   mov      ecx, eax                                       ;take a copy ref to ECX [19]
   mov      ebx, [ ebp ]                                   ;get the 'what' parameter -> EBX
   cmp      ebx, TYPE_REF_STACK                            ;is it the stack type?
   je       .create_stack                                  ;  if so, had better go create a stack instance
   test     ebx, ebx                                       ;is EBX zero (i.e. the data type)?
   je       .create_data                                   ;  if so, had better go create an instance of the data type

   ; -- OK, not a base-type - let's get on with the creation.

   shl      eax, 5                                         ;prepare to index the CDT at the new component's entry
   shl      ebx, 5                                         ;prepare to index the CDT at the type component's entry

%ifdef _DEBUG                                              ;Since create() is a privileged op, we don't really need to check parameters.  However, ...
   mov      edx, 2
   cmp   word  [ orb_cdt + ebx + CDT.cs_sel ], CDT.SEL_TYPE_TYPE      ;are we trying to create based on a bona fide type?
   jne   .throw0                                                      ;if not, we'd better throw an exception
%endif

   lea   edx, [ orb_cdt + ebx ]                            ;Get the addr of the type's CDT entry
   mov   [ orb_cdt + eax + CDT.type_ptr ], edx
   mov   word  [ orb_cdt + eax + CDT.ds_sel ], CDT.SEL_TYPE_UNCACHED    ;We don't have a selector associated with our DS yet
   mov   edx, [ orb_cdt + ebx + CDT.mtbl ]
   mov   [ orb_cdt + eax + CDT.mtbl ], edx
   mov   dword [ orb_cdt + eax + CDT.mcount ], 0           ;Note -- no methods yet (wait until constructor returns!)
   mov   dword [ orb_cdt + eax + CDT.call_count ], 1       ;Get ready for the ctor (could set it to zero, and then inc below, but what's the point?)
   mov   dx, [ orb_cdt + ebx + CDT.ds_sel ]                ;Get the code-segment (this IS ds_sel)
   mov   [ orb_cdt + eax + CDT.cs_sel ], dx                ;And store in CDT
   mov   dword [ orb_cdt + eax + CDT.gdt_lock ], 1         ;To start with the newly created objref is locked in GDT; It'll be unlocked at [7]

   ; -- We know the initial data is already in GDT from [20], but we also need
   ; to get the newly created ObjRef into the GDT cache (which we know it ain't)

   mov      edi, eax                                       ;can't keep new ref in EAX (will be clobbered by load_gdt): move to EDI
   shr      eax, 5
   push     eax                                            ;EAX contains the new ref, let's load its data segment into the GDT
   call     load_gdt
   add      esp, 4
   mov      edx, eax                                       ;place result in EDX [9]

   ; -- Have we any initial data?  If so we have to copy it in.

   mov      ebx, [ orb_cdt + ebx + CDT.init_ref ]
   test     ebx, ebx                                       ;is there any initial data?
   jz       short .init_data_handled                       ;if not, no point copying it in!

   ; -- Make sure that the init DS remains cached in the GDT too.
   ; Note we're ok to rely on load_gdt() for this!
   ; We know init DS is cached in GDT from call to LOCK at [20]

   shl      ebx, 5
   mov      esi, [ orb_cdt + ebx + CDT.ds_sel ]
   mov      gs, esi
   lsl      esi, esi
   inc      esi                                            ;note that it's LIMIT in esi: convert it to size.
   mov      ds, edx                                        ;new comp's selector is in DS (Recall that new comp's DS selector was placed in EDX at [9])

   test     esi, esi                                       ;check for zero initially so that we can place the test at the end of the loop (do loops more efficient than while)
   jz       short .copy_in_done                            ;if there's nothing to do, don't do any copying!
.copy_in_loop:
   sub      esi, 4
   mov      eax, [ gs : esi ]
   mov      [ esi ], eax
   jnz      .copy_in_loop                                  ; note that in esi is size => we loop while esi > 0.  This assumes no init data segs are bigger
                                                           ; than 2G, but that's ok as such a situation would exhaust linear space anyway!
.copy_in_done:
   mov      eax, ORB.DYNAMIC_SEL                           ; restore ORB ds after copying
   mov      ds, eax
   dec      dword [ orb_cdt + ebx + CDT.gdt_lock ]         ;!! FIXME on INIT_REF??? did we lock it?

.init_data_handled:
   mov      eax, edi                                       ;We need to return the newly created objref in EAX.

   ; -- OK, we've constructed the component itself;
   ; now we need to call it's constructor.
   ; However, we need to copy the constructor's
   ; parameters across before we can actually call it.

   shr      eax, 5                                         ;Since we pushad below, move objref
                                                           ;into EAX ready for the popad at [8]
   pushad                                                  ;Push away GP regs.

   mov      ebx, [ ebp + 8 ]                               ;get param_sz
   cmp      ebx, 0
   je       short .params_done

   ; -- Round up to nearest whole word.

   add      ebx, byte 3
   and      ebx, byte 0xFFFFFFFC                           ;ebx is no of bytes remaining to copy

   lea      edi, [ esp - (ORB.STACK_BUF + 8) ]             ; edi is pointer to dest of mem copy
                                                           ; (leave STACK_BUF bytes as normal,
                                                           ; and step over current_comp we push below.
                                                           ; It's +8 not +4 coz pushes go 4 bytes below)

   ; -- Copy parameters in

.cpy_loop:
   mov      eax, [ ebp + 12 + ebx - 4 ]                    ;copy param in.
                                                           ; Note that ebp+12 is start of params,
                                                           ; ebx is size_remaining, and we copy
                                                           ; from size_remaining-4.
   mov      [ ss : edi ], eax                              ;copy it out to start of shrunk stack.
   sub      edi, 4                                         ;slightly sub-optimal, but who cares?
   sub      ebx, 4
   jnz      .cpy_loop

.params_done:

   ; -- OK, parameters have been pushed; let's call the ctor

   push     dword [ current_comp ]                         ;Need to remember who called orb::create() [1]
   mov      eax, [ current_comp ]                          ;Pass the creator of the new component in EAX
   mov      [ current_comp ], ecx                          ;We're gonna be calling the object we're to create (ref copy was taken to ECX at [19])
   shl      ecx, 5                                         ;Change the ObjRef into an Index into the CDT      PU

   push esi
   outstring cr_ctor
   pop esi

   ; -- Need to set tcall_depth to zero, saving old tcall_depth away
   ; Also need to save the outgoing old_limit away too.

   ; Now lets emulate ORB.CALL/ORB.RET behavior...

   push  dword ORB.TEXT                                    ;push our CS and an EIP to make it look like the
   push  dword .ctor_return                                ;FAR CALL that RET will expect to have happened

   push  dword ORB.DYNAMIC_REF                             ;we're the caller, so push the ORB's reference     UV dependency
   mov   esi, [ active_stack ]                             ;Get stack element into ESI
   push  dword [ esi + STACK_EL.limit ]                    ;push the old limit                                NP
   push  dword [ esi + STACK_EL.tcall_els ]                ;push the old tcall-private-stack                  NP
                                                           ;Note: above 2 pushes might be cheaper via regs (pairing), but no regs free :-(
   mov   dword [ esi + STACK_EL.tcall_els ], 0

   ; -- Incrememnt call depth and dec lock count appropriately

   inc   dword [ esi + STACK_EL.call_depth ]               ;increment the call-depth                          UV

   push  dword [ esi + STACK_EL.old_esp ]                  ;push old esp for RET
   mov   [ esi + STACK_EL.old_esp ], esp

   ; -- Now we need to do the stack shrinking.  This means extracting
   ; the old-going limit, and setting the new one.
   ;
   ; 1) Extract old limit and store in stack element
   ; 2) Calc new limit and find stack's CDT entry
   ; 3) Write modified limit to stack's CDT and GDT entries

   mov      edi, ss                                        ;Get stack segment into EDI                        NP

   test     byte  [ orb_gdt + edi + 6 ], 0x80              ;Is the stack seg page or byte granularity?
   jnz      .page_gran_stack                               ;If it's page gran, we have do quite a lot

   mov      ebx, [ orb_gdt + edi + 4 ]                     ;get top half of stack's out-going descriptor
   and      ebx, 0x000F0000;                               ;extract out limit[19..16]
   mov      bx, [ orb_gdt + edi ]                          ;get limit[15..0] from stack's out-going descriptor
   mov      [ esi + STACK_EL.limit ], ebx                  ;Set the old SS.limit                              UV PAIR

   mov      esi, [ esi + STACK_EL.this_ref ]
   shl      esi, 5
   lea      ebx, [ esp - 1 ]                               ;Move esp - 1 into ebx (for new limit)             UV PAIR

   mov      [ orb_cdt + esi + CDT.descr ], bx              ;write the bottom 16 bits of new limit to CDT descr
   mov      [ orb_gdt + edi ], bx                          ;modify ss.limit  (sp - 1) -> gdt[ ss ].limit[0..15]) UV
   and      byte  [ orb_cdt + esi + CDT.descr2 + 2 ], 0xF0 ;wipe out the CDT's old limit [19..16]
   and      byte  [ orb_gdt + edi + 6 ], 0xF0              ;wipe out the GDT's old limit [19..16]
   and      ebx, 0x000F0000
   or       [ orb_cdt + esi + CDT.descr2 ], ebx            ;or in the CDT's new limit[19..16]
   or       [ orb_gdt + edi + 4 ], ebx                     ;or in the GDT's new limit[19..16]

   sub      esp, [ ebp + 8 ]                               ;effectively push constructor params
   mov      ss, edi                                        ;reload the stack segment.                         NP

   ; -- Finally, load method table and callee's DS and jump off to ctor

   mov      esi, [ orb_cdt + ecx + CDT.mtbl ]              ;load the method table pointer                     UV
   mov      ebx, ecx                                       ;copy (new ref << 5) to ebx for use in fault handler  UV PAIR  FIXME: change ref to ebx throughout routine

.ctor_ds_fault:                                            ;label coz this instr. might fault!
   mov      ds, edx                                        ;load target DS: was put in edx way back at [9]    NP
.ctor_cs_fault:
   jmp      far [ fs: esi + MT.ctor ]                      ;jump into according to mt.                        NP

   ; -- We get here after ctor executes `jmp ORB.CALL : ORB.RET`

.ctor_return:
   pop   dword [ current_comp ]                            ;restore our caller from the push at [1]
   popad                                                   ;pop back regs (note that the objref is in eax from [8])

   push esi
   outstring cr_ctored
   pop esi
   
   ; -- Release the new instance's GDT cache lock, restore context and return
   ; Also, we can let other's in now: set mcount to real value (rather than
   ; the dummy value of zero as it was before to prevent callers)

   mov      esi, eax                                       ;copy it to esi (we don't want to trash eax...
   shl      esi, 5                                         ;...trash esi instead!)
   mov      ebx, [ ebp ]                                   ;get the type
   shl      ebx, 5
   mov      edx, [ orb_cdt + ebx + CDT.mcount ]            ;get the type's real method count
   mov      [ orb_cdt + esi + CDT.mcount ], edx            ;We have now created a fully-fledged component: set mcount to it's real value
   dec      dword [ orb_cdt + esi + CDT.gdt_lock ]         ;let go of the GDT lock on the newly created ref before returning (lock claimed at [7])
   jmp      .done_create

.page_gran_stack:                                          ;FIXME -- deal with page gran stacks here
   cli
   mov      ax, ORB.VIDEO_SEL
   mov      gs, ax
   mov dword [gs:0], 'PNSN'
   mov dword [gs:4], 'TNKN'                                ;print PSTK halt message
   jmp short $

.create_stack:                                             ;WARNING: link_to had better not disappear! !!ORB DOES NOT CHECK THIS!!
%ifdef _DEBUG
   cmp   dword [ ebp + 8 ], 12                             ;Stack needs 12 bytes of parameters: size, link_to and resume_ctx
   jne   .throw0                                           ;If not, wrong ctor parameters: throw exception!
   mov      ecx, [ ebp + 16 ]                              ;If so, check link_to is ok
   test     ecx, ecx                                       ;and it with itself
   jz   .param_ok                                          ;if link_to is zero, no need to check -- create a data component as normal first
   shl      ecx, 5                                         ;otherwise, link_to had better be a stack
   cmp   dword [ orb_cdt + ecx + CDT.type_ptr ], TYPE_PTR_STACK    ;is it?
   jne      .params_bad                                    ;it not, Houston we have a problem...
   mov      ecx, [ orb_cdt + ecx + CDT.stack ]             ;get link_to's MT ptr, which, if it's a stack, is overloaded to be the addr of it's stack element
   cmp   dword [ ecx + STACK_EL.next_ref ], 0              ;If link_to is non-zero, link_to->link had better be zero (i.e. end of stack-chain)
   je  .param_ok                                           ;if so, params are ok -- create a data component as normal first

.params_bad:
   add      esp, 4
   popad
   add      esp, 4
   mov      edx, 1                                         ; FIXME: BOGUS MAGIC
   jmp      throw_invalid_xcp
%endif

   ;-------------------------------------------------------------
   ;Create a data component.
   ;  EAX contains the reference
.create_data:
%ifdef _DEBUG
   cmp   dword [ ebp + 8 ], 4                              ;must have single dword parameter - the block size to reserve (?FIXME)
   jne      .params_bad
%endif

.param_ok:

   ; -- Set up the CDT entry

   push  eax
   shl   eax, 5
   add   eax, orb_cdt
   mov   word  [ eax + CDT.ds_sel ], CDT.SEL_TYPE_UNCACHED ;init cdt[].DS (no selector allocated yet)
   mov   word  [ eax + CDT.cs_sel ], CDT.SEL_TYPE_INVALID  ;data components don't have a CS
   mov   dword [ eax + CDT.mcount ], 0                     ;init cdt[].mcount
   mov   dword [ eax + CDT.call_count ], 0                 ;init cdt[].call_count
   mov   dword [ eax + CDT.type_ptr ], TYPE_PTR_DATA       ;init cdt[].type_ref
   mov   dword [ eax + CDT.gdt_lock ], 0                   ;init cdt[].gdt_lock. FIMXE: do this before allocing the segment when we fixed
   pop   eax
   cmp   ebx, TYPE_REF_STACK                               ;is it a stack type then?
   jne   near  .done_create


   ;-----------------------------------------------------------------------
   ;So, we wish to create a stack component eh?
   ;first off, grab a stack-element from the free-list in thread-safe but non-blocking fashion

   pushad                                                  ;FIXME: we can probably get away without this! (at least just save EAX)
.get_stack_el:
   mov      ecx, eax                                       ;remember our reference in ecx
   mov      eax, [ stack_el_fl ]                           ;take local copy of free-list ptr
   test     eax, eax                                       ;and free-list ptr with itself
   jz   .nomem                                             ;if it's zero, we're out of stack memory!
   mov      ebx, [ eax ]                                   ;get free-list el's link ptr
   cmpxchg     [ stack_el_fl ], ebx                        ;place link ptr, thus claiming stack element
   jne      .get_stack_el                                  ;however, if free-list changed in mean time, we don't know what's going on so start again.


   ;-----------------------------------------------------------------------
   ;now, grab space for the nomem_xcp to avoid dead-lock later on

   cmp      byte  [ first_stack ], 0
   jne      .first_stack
   mov      ebx, eax                                       ;take a copy of the stack-element
   push     dword ORB.XCP_NOMEM_TYPE
   call     make_orb_xcp                                   ;create the exception
   add      esp, 4
   mov      [ ebx + STACK_EL.nomem_xcp_ref ], eax          ;remember the exception's ref
   mov      [ ebx + STACK_EL.nomem_xcp_ptr ], edx          ;and remember the exception's address
   mov      eax, ebx                                       ;restore the stack element pointer into EAX
.first_stack:
   mov   byte  [ first_stack ], 0


   ;-----------------------------------------------------------------------
   ;Got ourselves a stack element in eax -- let's set stuff up
   ;eax = stack element addr; ebx = link_to's ref; ecx = new stack's ref

   mov      ebx, [ ebp + 16 ]                              ;get link_to parameter
   mov      [ eax + STACK_EL.this_ref ], ecx
   mov      [ eax + STACK_EL.prev_ref ], ebx               ;link to link_to's reference (0 if we're not linking in)
   mov   dword [ eax + STACK_EL.next_ref ], 0              ;we will be the final one in stack-chain
   mov   dword [ eax + STACK_EL.next_ptr ], 0              ;we will be the final one in stack-chain
   mov   word  [ eax + STACK_EL.next_ss ], STACK_EL.END_OF_CHAIN   ;we have no next
   mov   dword [ eax + STACK_EL.call_depth ], 0            ;call-depth of zero to start with
   mov   dword [ eax + STACK_EL.tcall_els ], 0             ;like-wise the tcall count
   mov   dword [ eax + STACK_EL.prev_ss ], STACK_EL.END_OF_CHAIN   ;we assume we have no "prev" (will get corrected at [4] if this assumption is wrong)
%ifdef _DEBUG
   mov   dword [ eax + STACK_EL.prev_esp ], 0xFFFFFFFF     ;mark prev_esp as -1 to indicate there are no fcalls pending on this stack (note this is only used in debug builds)
%endif
   shl      ecx, 5                                         ;we need to access our CDT
   inc   dword [ orb_cdt + ecx + CDT.gdt_lock ]            ;take a GDT lock on our DS. Do this before pointing at here from CDT because only stack-els not
                                                           ;referenced or on the free-list may be moved around (unless locked of course).
   mov      [ orb_cdt + ecx + CDT.stack ], eax             ;point our CDT mtable at our stack-el
   mov   dword [ orb_cdt + ecx + CDT.type_ptr ], TYPE_PTR_STACK   ;We're a stack (CDT entry previously built as though we were a NULL)
   shr      ecx, 5

   test     ebx, ebx                                       ;do we have a link?
   jz       .no_link                                       ;we don't


   ;-----------------------------------------------------------
   ;OK, we handle linking up with previous stack element here
   ;edx = link_to's stack_el addr; di = link_to's DS
	
   shl      ebx, 5                                         ;need to access link_to's CDT
   inc      dword [ orb_cdt + ebx + CDT.gdt_lock ]         ;take a GDT lock on link_to's ref
   mov      edx, [ orb_cdt + ebx + CDT.stack ]             ;get link_to's stack-el address -> edx
   mov      di, [ orb_cdt + ebx + CDT.ds_sel ]             ;get link_to's DS -> di
   mov      [ eax + STACK_EL.prev_ss ], di                 ;set our prev_ss field appropriately (note: we're correcting the erroneous assumption made at [4])
   shr      ebx, 5                                         ;finished with link_to's CDT (for now)
   mov      [ edx + STACK_EL.next_ref ], ecx               ;set link_to->next_ref to us (note: we're not thread-safe, but says so in contract)
   mov      [ edx + STACK_EL.next_ptr ], eax               ;set link_to->next_ptr to our stack-element
   mov      [ eax + STACK_EL.prev_ptr ], edx               ;set our prev_ptr to link_to's stack-element

   shl      ecx, 5                                         ;we need to access our CDT entry
   mov      esi, [ orb_cdt + ecx + CDT.ds_sel ]            ;find out our DS
   shr      ecx, 5
   mov      [ edx + STACK_EL.next_ss ], si                 ;set link_to->next_SS to our DS
   mov      esi, [ ebp + 12 ]                              ;get the size parameter once more
   mov      [ edx + STACK_EL.next_esp ], esi               ;set link_to->next_esp to our size


   ;-------------------------------------------------------------------------------------------
   ;Done linking link_to to us, now we have to set up the stack so that switch_stack will work

.no_link:
   shl      ecx, 5
   mov      esi, [ ebp + 12 ]                              ;get new stack's size -> esi
   sub      esi, 8                                         ;ESP 8 bytes down since switch_stack will pop off STACK_EL.next_esp and current_comp
   mov      [ eax + STACK_EL.next_esp ], esi
   mov      ebx, [ ebp + 20 ]                              ;get new stack's resume_ctx
   test     ebx, ebx                                       ;see if it was zero (default argument)
   jnz      short .resume_override                         ;if resume_ctx is zero, make it m_current
   mov      ebx, [ current_comp ]
.resume_override:
   mov      [ eax + STACK_EL.resume_ctx ], ebx
   ;dec  dword [ orb_cdt + ecx + CDT_LOCK_OFFS ]           ;release our GDT lock    FIXME??
   popad                                                   ;restore all regs, including our reference->eax


   ;----------------------------------------------------------------------------
   ;OK, we've created one ObjRef.  Create the next, or go home

.done_create:
   inc   eax                                               ;get ready go and create the next ObjRef[17]
   dec   dword [ esp ]                                     ;we've made one, so subtract the amount remaining that we stacked at [14]
   jnz   .create_loop                                      ;are there any left?  If so, go back and create

   add      esp, 4                                         ;jump over the local variable we made at [14]
   pop      ebx                                            ;get the original amount of ObjRefs we were asked to create[16]
   sub      eax, ebx                                       ;need to subtract it from EAX due to the INCs at [17]
   mov      [ esp + 28 ], eax                              ;clobber the saved eax with the return value
   mov      ebx, [ current_comp ]
   shl      ebx, 5
   mov      ds, [ orb_cdt + ebx + CDT.ds_sel ]             ;restore caller's DS
   popad
.exit:
   retf

.throw0:
   add      esp, 4
   popad
   add      esp, 4
   jmp      throw_invalid_xcp

.nomem:                                                    ;There was no memory for stack element -- throw exception to get some
   push  dword STACK_EL_size                               ;We need STACK_EL_size bytes
   push  dword ORB.XCP_NOMEM_TYPE                          ;Throw the nomem type
   call     throw_gp_xcp                                   ;Throw it
   add      esp, 8
   jmp      .get_stack_el                                  ;Now let's try and get some mem again...



;/*-----------------------.
;|  grab_multi_refs       |
;|  grab_ref              |
;|------------------------'-------------------------------------------------------------.
;| Two helper functions to grab one or more ObjRefs                                     |
;|                                                                                      |
;|  - grab_multi_refs( uint i )                                                         |
;|  take i contiguous ObjRefs returning first one in EAX                                |
;|       -- called from method_create                                                   |
;|                                                                                      |
;|  - grab_ref()                                                                        |
;|  take just one ObjRef returning in EAX                                               |
;|       -- called from method_install                                                  |
;`-------------------------------------------------------------------------------------*/
ALIGN 16
grab_multi_refs:
   push     edx
   mov      eax, [ esp + 8 ]
   bsr      edx, eax                                       ;BSR (bit-set reverse) -- work out the highest order bit
   jmp      short do_the_grab

ALIGN 16
grab_ref:
   push     edx
   xor      edx, edx

do_the_grab:
   push     ecx
   push     ebx
.try_grab:
   mov      eax, [ cdt_fl + edx * 4 ]
   test     eax, eax
   jnz      short .got_ref                                 ;if cdt_fl is zero we've got to end of free list
   xor      ecx, ecx
   push     dword .try_grab
   jmp      short grow_fl

.got_ref:
   shl      eax, 5

   mov      ebx, [ orb_cdt + eax + CDT.next ]              ;get cdt_fl->next
   shr      eax, 5                                         ;get back to reference from CDT index
   cmpxchg  [ cdt_fl + edx * 4 ], ebx                      ;...and write it to free-list base: i.e. free_list_base = free_list_base->next
   jne      .try_grab                                      ;if the above failed, we'd better try again

   push     eax
   mov      ebx, eax
.adjust_max_ref:
   mov      eax, [ max_ref ]
   cmp      eax, ebx
   jg       short .no_extend
   cmpxchg  [ max_ref ], ebx
   jne      .adjust_max_ref                                ;must be careful about race condition here

.no_extend:
   pop      eax
   pop      ebx
   pop      ecx
   pop      edx
   ret



;/*-----------------------.
;|  grow_fl               |
;|------------------------'-------------------------------------------------------------.
;| An internal function to grow the fl stored in ecx.                                   |
;| - called from grab_ref                                                               |
;|                                                                                      |
;| Input:                                                                               |
;|    ECX = fl                                                                          |
;`-------------------------------------------------------------------------------------*/
ALIGN 16
grow_fl:
   pushad                                                  ;could we get rid of this shit?
;   push     ds                                            ;grab_refs (and therefore grow_fl) is called from
;   mov      eax, ORB.DYNAMIC_SEL                          ;method_create and method_install only, and both
;   mov      ds, eax                                       ;use DYNAMIC_SEL, so no need for it here...

   ; -- OK, we need to grow the free-list in ecx.  Grab the space by growing the
   ; ORB's static segment.
   ; EBX=pointer to new CDT entry; EAX=ref of new CDT entry;
   ; ESI=number of refs in this block; EDI=number of bytes in a block

   mov      ebx, FL_GROW_DELTA * CDT_size
   xadd     [ static_ds_size ], ebx                        ;grab some space for new FL.  EBX now contains start of space
   mov      eax, ebx
   sub      eax, orb_cdt                                   ;EAX contains addr of top of CDT.  Convert it into the first out-of-range reference
   shr      eax, 5                                         ;EAX now contains the first out-of-range reference
   mov      edx, eax
   add      edx, FL_GROW_DELTA                             ;EDX now contains the last ref we create
   mov      esi, 1
   shl      esi, cl                                        ;ESI now contains the number of refs per block (ECX == 0 from grab_refs)
   mov      edi, esi
   shl      edi, 5                                         ;EDI now contains the number of bytes in a block

   ; -- Create a free list of appropriate size

.create_entry:
   add      eax, esi                                       ;EAX is the next reference we'll create
   mov      dword [ ebx + CDT.ds_sel ], 0xFFFFFFFF         ;The reference we're creating is invalid to start with
   mov      dword [ ebx + CDT.next ], eax                  ;Link to the next one
   add      ebx, edi                                       ;Move EBX to point at next reference we'll create
   cmp      eax, edx                                       ;Have we just created the last one? (i.e. the 'next' ptr points at the first invalid ref)
   jl       .create_entry
   sub      ebx, edi                                       ;Oops -- move back to the ptr to the last ref we created...
   mov      dword [ ebx + CDT.next ], 0                    ;... and put zero there to terminate the free list.

   pushfd                                                  ;obtain spinlock
   cli

   ; -- Now link in the newly created refereces.

   sub      edx, FL_GROW_DELTA                             ;reset EDX to the first reference of the load we've just created
.link_ref:
   mov      eax, [ cdt_fl + ecx * 4 ]
   mov      [ ebx + CDT.next ], eax
   cmpxchg  [ cdt_fl + ecx *  4 ], edx
   jne      .link_ref                                      ;if it didn't work (due to race), try again!

   ; -- Now grow the STATIC selector

   mov      ebx, [ static_ds_size ]                        ;get the new top of the static segment
   dec      ebx                                            ;convert from a "size" to a "limit"
   cmp      ebx, 0xFFFFF                                   ;is it bigger than 1M? (i.e. is it page aligned?)
   jle      .byte_align
   shr      ebx, 12                                        ;divide limit by page size
   or       ebx, 0x00800000                                ;set descr to page gran
.byte_align:
   mov      [ orb_gdt + ORB.STATIC_SEL ], bx               ;write limit 15..0
   mov      ecx, [ orb_gdt + ORB.STATIC_SEL + 4 ]
   and      ecx, 0xFFF0FFFF                                ;mask out limit 19..16
   and      ebx, 0x008F0000                                ;mask out all but limit 19..16 and G
   or       ecx, ebx
   mov      [ orb_gdt + ORB.STATIC_SEL + 4 ], ecx          ;put it back into GDT
   popfd                                                   ;release the spinlock
;   pop      ds                                            ;see above why this is unnecessary
   popad
   ret

section .data
stringz cr_ctor, {"CREATE: calling ctor on ",EOL}
stringz cr_ctored, {"CREATE: called ctor",EOL}


;========================================================================================
; EOF
;========================================================================================
