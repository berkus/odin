;========================================================================================
;
; Type installation
;
;========================================================================================

GLOBAL method_install

EXTERN grab_ref
EXTERN desc.set_entry
EXTERN desc.get_limit
EXTERN desc.set_limit
EXTERN desc.set_type
EXTERN desc.get_base


%define ___COMPILE_ORB_CONSOLE
%include "orb.inc"
%include "cdt.inc"
%include "orb_link.inc"
%include "type.inc"
%include "comp.inc"
%include "desc.inc"
%include "mt.inc"
%include "Console.inc"
%include "debug.inc"


section .text
bits 32

;====================================== INSTALL =========================================
; Install a type
;
; input:
;  EBX = from_ref
;  ECX = [caller_ds = 0] ???
;  EDX = [offs = 0]      ???
;  ESI = [caller_cs = 0] ???
;uint orb_impl::install( uint from_ref, uint caller_ds, uint offs, uint caller_cs )
;
; output:
;  EAX = from_ref
;  other registers unmodified
;
method_install:
   push     ds
   push     ebx
   push     ecx
   push     edx
   push     esi
   push     edi

   mov      eax, ORB.DYNAMIC_SEL
   mov      ds, eax

   outstring installing_a
   outdword  ebx

   push ebx                                                ; save objref [1]
   shl ebx, 5                                              ; turn into CDT ptr
   add ebx, orb_cdt                                        ; convert ebx to CDT as there's alot of CDT manipulation ahead

   cmp dword [ebx + CDT.type_ptr], TYPE_PTR_DATA
   je  short .type_check_ok

   ; -- let's panic!

   mov esi, str_ref
   call console__print
   push edx                                                ; save offs
   mov edx, ebx
   shr edx, 5
   call console__print_dword
   mov esi, str_is_of_type
   call console__print
   mov edx, [orb_cdt + ebx + CDT.type_ptr]
   call console__print_dword
   call console__newline
   mov esi, str_called_from_offs
   call console__print
   pop edx                                                 ; restore offs
   call console__print_dword
   mov esi, str_in
   call console__print
   mov edx, ecx
   call console__print_dword
   mov esi, str_ref2
   call console__print
   shr edx, 2                                              ; /4 = /8*2 = convert sel to rev_tbl index
   mov edx, [ rev_tbl + edx ]
   call console__print_dword
   call console__newline
   mov esi, str_panic
   call console__print
   ; don't forget to rewind stack if you gonna throw an exception here
   cli
   jmp short $

.type_check_ok:
   inc   dword [ebx + CDT.gdt_lock]                ; lock it [*]
   movzx eax, word [ebx + CDT.ds_sel]
   cmp   eax, CDT.SEL_TYPE_UNCACHED
   jne   short .cached

   call load_gdt                                           ; load DS into GDT (objref is on stack from [1])

.cached:
   add  esp, 4                                             ; restore stack (restore anyway because need to wipe out [1] from stack)

   ; EAX = type DS
   ; EBX = from_ref as CDT entry

   mov  esi, orb_gdt                                       ; for desc.* calls
   call desc.get_limit
   inc  ecx                                                ; ECX = type DS size

   push ebx                                                ; don't trash from_ref
   call desc.get_base
   mov edx, ebx                                            ; EDX = lin_base [*]

   push edx                                                ; don't trash lin_base neither

   outstring from_ds
   outdword  eax
   outstring with_base
   outdword  ebx
   outstring and_size
   outdwordn ecx

   pop edx                                                 ; restore lin_base
   pop ebx                                                 ; restore from_ref

   ; -- Access comp_desc via esi, mt via edi

   mov esi, ecx                                            ; esi = segment size
   sub esi, COMP_DESC_size                                 ; esi -> comp_desc in type DS
   add esi, edx                                            ; convert COMP_DESC pointer to ORB relative
   sub esi, [orb_linear]                                   ; (comp_desc + lin_base - orb_linear)

   mov edi, [esi + COMP_DESC.mt_start]                     ; edi -> mt in type DS
   add edi, edx                                            ; convert MT pointer to ORB relative address
   sub edi, [orb_linear]                                   ; (mtbl + lin_base - orb_linear)

   ; -- Install the method table

   mov dword [ebx + CDT.mtbl], edi                         ; point CDT at new MT

   push eax                                                ; store away type DS for later [3]
   mov ax, [ebx + CDT.ds_sel]                              ; load type CS

   ; -- Update MT with new CS

   mov [edi + MT.ctor_cs], ax                              ; update ctor CS
   mov [edi + MT.dtor_cs], ax                              ; update dtor CS

   mov  ecx, [edi + MT.mcount]
   push ecx                                                ; store away method count for later [2]
   test ecx, ecx
   jz   short .no_methods

.fill_methods:
   mov  [edi + MT.methods + ecx * 8 + MT_ENTRY.cs - 8], ax ; update each entry cs
   loop .fill_methods

   ; -- Create an init data segment, and make from_ref the new code segment.

.no_methods:
   xor ecx, ecx                                            ; init_ref

   cmp dword [esi + COMP_DESC.data_size], 0
   je  short .no_init_data

   ; -- Only create an initial data segment if there is any initial data!

   call grab_ref
   mov ecx, eax                                            ; obtained new ref

   shl ecx, 5                                              ; convert to CDT ptr
   lea edi, [orb_cdt + ecx]                                ; load CDT ptr

   mov word  [edi + CDT.ds_sel], CDT.SEL_TYPE_UNCACHED     ; The initial DS is not cached in GDT to start with
   mov word  [edi + CDT.cs_sel], CDT.SEL_TYPE_INIT_DS
   mov dword [edi + CDT.gdt_lock], 0
   mov dword [edi + CDT.mcount], 0
   mov dword [edi + CDT.init_ref], 0xFFFFFFFF

   ; -- Create init_ref descriptor

   push ebx                                                ; save from_ref
   push ecx                                                ; save init_ref
   push esi                                                ; save comp_desc

   xor eax, eax
   mov ebx, edx                                            ; segment lin base (loaded to EDX at [*])
   add ebx, dword [esi + COMP_DESC.data_start]
   mov ecx, [esi + COMP_DESC.data_size]
   mov edx, DESC.RO_DATA | DESC.BYTE_GRAN                  ; FIXME old sz2limit was done incorrectly, need a fix here to account for gran
   lea esi, [edi + CDT.descr]                              ; load descriptor ptr
   call desc.set_entry                                     ; create the descriptor

   pop esi
   pop ecx
   pop ebx

.no_init_data:

   ; -- Finally, update from_ref to make it the type
   ; EBX = from_ref as CDT entry
   ; ECX = init_ref as CDT ptr
   ; ESI = comp_desc

   shr ecx, 5                                              ; turn back into objref
   mov dword [ebx + CDT.init_ref], ecx                     ; store init data seg

   pop ecx                                                 ; restore mcount stored at [2]
   mov dword [ebx + CDT.mcount], ecx
   mov ecx,  [esi + COMP_DESC.bss_size]                    ; load bss size from COMP_DESC
   mov dword [ebx + CDT.bss_sz], ecx                       ; store bss size

   ; -- Modify from_ref cdt descriptor limit and access

   mov ecx, [esi + COMP_DESC.text_size]                    ; load incoming segment size
   lea esi, [ebx + CDT.descr]                              ; update from_ref CDT descriptor
   xor eax, eax                                            ; no offset from esi
   call desc.set_limit

   mov edx, DESC.XR_CODE                                   ; turn into code seg
   call desc.set_type

   pop eax                                                 ; restore type DS stored at [3]
   mov ecx, [ebx + CDT.descr1]                             ; copy descriptor to GDT
   mov [orb_gdt + eax], ecx                                ;  |
   mov ecx, [ebx + CDT.descr2]                             ;  |
   mov [orb_gdt + eax + 4], ecx                            ; /

   mov word  [ebx + CDT.cs_sel], CDT.SEL_TYPE_TYPE         ; we're a proper type now!

   dec dword [ebx + CDT.gdt_lock]                          ; unlock it (locked at [*])

   pop  edi
   pop  esi
   pop  edx
   pop  ecx
   pop  ebx
   pop  ds
   mov  eax, ebx                                           ; return from_ref
   retf


section .data

stringz installing_a, {"[ORB] Installing a "}
stringz from_ds,      {" from ds "}
stringz with_base,    {", base "}
stringz and_size,     {", size "}
str_ref:              db EOL,"[PANIC] ref ", 0
str_is_of_type:       db " is of type: ",0
str_called_from_offs: db "[PANIC] called from offset ",0
str_in:               db " in ",0
str_ref2:             db " -- ref: ",0
str_panic:            db "[PANIC] FIXME: throw xcp_orb_invalid from install!",0

