;========================================================================================
;
; Selector and reference management
;
;========================================================================================

GLOBAL method_get_type
GLOBAL method_get_self
GLOBAL method_set_type
GLOBAL method_sel2ref
GLOBAL method_set_desc
GLOBAL method_get_stack
GLOBAL method_reject
GLOBAL method_linear

EXTERN method_create.create_loop ; for method_set_type


%include "orb.inc"
%include "cdt.inc"
%include "orb_link.inc"
%include "stack.inc"
%include "type.inc"


section .text
bits 32

;=========================================== GET_TYPE ===================================
; input:
;  EBX = ref
; output:
;  EAX = type
;
method_get_type:
   push     ds
   mov      eax, ORB.STATIC_SEL
   mov      ds,  eax
   shl      ebx, 5
.ds_fault:
   mov      eax, [ orb_cdt + ebx + CDT.type_ptr ]          ;get the address of the type's CDT entry
   sub      eax, orb_cdt                    ;subtract the base of the CDT to get index into array
   shr      eax, 5                         ;and of course, convert from an index to an ObjRef
   shr      ebx, 5                         ;return ebx to what it was previously
   pop      ds
   retf


;=========================================== GET_SELF =====================================
; input:
;  -
; output:
;  EAX = self ref
;
method_get_self:
   push     ds
   mov      eax, ORB.STATIC_SEL
   mov      ds,  eax

   mov      eax, [ current_comp ]

   pop      ds
   retf


;================================= SET_TYPE ============================================
; input:
;  EBX = ref
;  ECX = strong ( 0 = weak, 1 = strong, 2 = brutal )
;  on stack (simulates method_create)
;  [esp]   = type to set to
;  [esp+4] = where to instantiate (FIXME?)
;  [esp+8] = 0
;
; output:
;  EAX = ref of new type
;
method_set_type:

   ; don't save ds, because method_create will reload it anyway.

   mov      eax, ORB.STATIC_SEL
   mov      ds, eax
   shl      ebx, 5
   cmp      ecx, 2
   je       short .force
   mov      eax, [ orb_cdt + ebx + CDT.call_count ]
   test     eax, eax
   jnz      short .exit

   mov      eax,  [ orb_cdt + ebx + CDT.mcount ]
   mov      dword [ orb_cdt + ebx + CDT.mcount ], 0        ;block off other calls
   cmp      dword [ orb_cdt + ebx + CDT.call_count ], 0 ;!!FIXME again?
   jne      short .abort

.force:

   ; -- ok, get on with the swap

   mov      byte  [ orb_cdt + ebx + CDT.call_count ], 1    ;gonna turn it into a zombie when we destroy below
   mov      eax, 1
   shr      ebx, 5
   push     dword [ current_comp ]
   mov      dword [ current_comp ], 0                      ;we call from us, so we want to return to ORB
   METHOD_DESTROY                                          ;destroy, turning into a zombie so as to keep the reference available
   pop      dword [ current_comp ]

   ; -- Now we need to create the new one on reference EBX.
   ; We hack a jump into create

   mov      eax, 1                                         ;we're just creating the one
   pushad                                                  ;create does this, so we'd better
   push     eax                                            ;store away the total number of ObjRefs we've been asked to create [16]
   lea      ebp, [ esp + 44 ]                              ;[esp] = 'how many'; [esp+4] = regs, [esp+36] = caller EIP, [ esp + 40 ] = caller CS, [ esp + 44 ] = first type
                                                           ;[ebp] = what, [ ebp + 4 ] = where, [ ebp + 8 ] = param_count

   ; -- Find the appropriate ObjRef free-list to put stuff on

   push     eax                        ;put the 'ObjRef count' parameter on the stack (but leave it there)
   mov      eax, ebx                   ;simulate the call to grab_multi_refs returning our reference
   jmp      method_create.create_loop  ; method_create will return to the caller

.exit:
   shr      ebx, 5
   mov      eax, [ current_comp ]
   shl      eax, 5
   mov      ds, [ orb_cdt + eax + CDT.ds_sel ]
   xor      eax, eax                   ;set EAX to zero indicating that the set_type failed
   retf

.abort:
   test     ecx, ecx
   jnz      .exit

   ; -- if ECX is zero, this means that the change is weak,
   ; so we need to set mcount back to let others in

   mov   dword [ orb_cdt + ebx + CDT.mcount ], eax          ;re-instate the method count
   jmp      .exit


;=========================================== SEL2REF =====================================
; Convert selector to reference
;
; input:
;  EBX = selector
;
; output:
;  EAX = objref
;
method_sel2ref:
   cmp      ebx, ORB.GDT_SZ * 8
   jge      throw_invalid_xcp
   push     ds
   mov      eax, ORB.STATIC_SEL
   mov      ds,  eax
   and      ebx, 0xFFF8                                    ; drop any rpl type crap
   shr      ebx, 1
   mov      eax, [ rev_tbl + ebx ]
   shl      ebx, 1
   pop      ds
   retf


;=========================================== SET_DESC ===================================
; Change the component with ObjRef in ebx's descriptor arbitrarily.
; Beware: attempting to change an in-use component
; might cause a GPF next time it's DS is loaded (can't load DS with seg where S=0).
;
; input:
;  EBX = ref
;  ECX = OR_DESC1
;  EDX = OR_DESC2
;  ESI = AND_DESC1
;  EDI = AND_DESC2
;
; output:
;  ECX = DESC1
;  EDX = DESC2
;
method_set_desc:
   push     ds
   mov      eax, ORB.STATIC_SEL
   mov      ds,  eax

   push     ebx                                            ;save the ObjRef on the stack for use at [*]
   shl      ebx, 5
   cmp      word  [ orb_cdt + ebx + CDT.ds_sel ], 0xFFFF   ;if an invalid objref is supplied...
   je       short .invalid_ref                             ;...throw an exception

   ; -- First fix the CDT.  Then bring descr into the GDT if cached

   mov      eax, [ orb_cdt + ebx + CDT.descr1 ]            ;Do it RISC style because
                                                           ;(a) makes change to CDT atomic and
                                                           ;(b) quicker on P6
   and      eax, esi                                       ;and out whatever bits required
   or       eax, ecx                                       ;or in whatever bits required
   mov      [ orb_cdt + ebx + CDT.descr1 ], eax            ;Move it back into CDT

   mov      eax, [ orb_cdt + ebx + CDT.descr2 ]            ;now deal with upper 32 bits of descriptor
   and      eax, edi                                       ;and out whatever bits required
   or       eax, edx                                       ;or em in
   mov      [ orb_cdt + ebx + CDT.descr2 ], eax            ;Move it back into CDT

   ; -- Now change the GDT if needs be (race: ensure that the GDT
   ; entry is not rejected if ObjRef is cached)

   inc      dword [ orb_cdt + ebx + CDT.gdt_lock ]         ;lock the in-coming DS selector in the GDT
   movzx    ebx, word [ orb_cdt + ebx + CDT.ds_sel ]       ;get the selector
   cmp      ebx, CDT.SEL_TYPE_UNCACHED                     ;check that the selector is cached in the GDT
   jne      short .noload2
   call     load_gdt                                       ;[*] if not, better bring it in (note, the ObjRef is already pushed onto the stack)
.noload2:
   mov      ecx, [ orb_cdt + ebx + CDT.descr1 ]            ;get desc1 -> ecx
   mov      edx, [ orb_cdt + ebx + CDT.descr2 ]            ;get desc2 -> edx
   mov      [ orb_gdt + ebx ],     ecx                     ;set lower descr work from GDT as well as CDT
   mov      [ orb_gdt + ebx + 4 ], edx                     ;set upper descr word from GDT as well as CDT
   pop      ebx
   shl      ebx, 5
   dec      dword [ orb_cdt + ebx + CDT.gdt_lock ]         ;unlock the in-coming DS selector from the GDT
   pop      ds
   retf

.invalid_ref:
   pop      ebx
   mov      ecx, ORB.XCP_NOREF_TYPE
   jmp      throw_fatal_xcp


;======================================= GET_STACK =======================================
; input:
;  EBX = stack objref (or 0 for stack relative to active)
;  ECX = walk
;
; output:
;  EAX = stack objref
;
method_get_stack:
   push     ds
   push     ebx
   mov      eax, ORB.DYNAMIC_SEL
   mov      ds,  eax

   test     ebx, ebx                    ;is ebx zero?
   jnz      short .stack_supplied

   mov      ebx, [ active_stack ]       ;if so it means we get stack relative to the active one
   jmp      short .got_init_stack

.stack_supplied:
   shl   ebx, 5
%ifdef _DEBUG
   cmp   dword [ orb_cdt + ebx + CDT.type_ptr ], TYPE_PTR_STACK ;if a stack reference is supplied, it had better be a stack
   jne   short .stk_type_error
%endif
   mov   ebx, [ orb_cdt + ebx + CDT.stack ]                ;get the stack element

.got_init_stack:

	; -- we've got the stack now (either supplied or current), now we need to
	; walk the stack-chain ecx steps, but which way?

   test     ecx, ecx                                       ;if ecx's zero, we have the stack already
   jz       short .got_final_stack
   cmp      ecx, 0
   js       short .walk_back                               ;if the sign-bit is set, ecx is -ve, so walk backwards

.walk_forwards:
   mov      ebx, [ ebx + STACK_EL.next_ptr ]               ;walk-on one more step
   test     ebx, ebx
   jz       short .off_end_of_stack                        ;it looks like there weren't as many stacks as we hoped for!
   dec      ecx                                            ;we've walked on one, so dec the walk-count
   jnz      .walk_forwards                                 ;if there are any more walks pending, we'd better do them!
   jmp      short .got_final_stack

.walk_back:
   mov      ebx, [ ebx + STACK_EL.prev_ptr ]               ;walk-on one more step
   test     ebx, ebx
   jz       short .off_end_of_stack                        ;it looks like there weren't as many stacks as we hoped for!
   inc      ecx                                            ;we've walked on one, so dec the walk-count
   jnz      .walk_back                                     ;if there are any more walks pending, we'd better do them!

	; -- Once control gets here we have the stack we're interested in

.got_final_stack:
   mov      eax, [ ebx + STACK_EL.this_ref ]               ;return the stack's /reference/ not the address of the stack element!
   pop      ebx
   pop      ds
   retf

.off_end_of_stack:                                         ;there weren't as many stacks as the caller hoped for! (i.e. ecx was out-of-range).
   xor      eax, eax                                       ;instead of throwing an exception we return zero, because this can be used to find
   pop      ebx                                            ;out if there are any stacks at end of chain, so since out-of-bounds ecx is unexceptional
   pop      ds                                             ;we should not indicate this case with an exception!
   retf

%ifdef _DEBUG
.stk_type_error:
   mov      edx, [ orb_cdt + ebx + CDT.type_ptr ]
   mov      edx, 0xdeadbeef
   pop      ebx
   add      esp, 4
   jmp      throw_invalid_xcp
%endif


;======================================== REJECT ====================================
;
; input:
;  EBX = ref to reject
;
; output:
;  -
;
method_reject:
   push     ecx
   push     ebx
   push     ds
   mov      eax, ORB.STATIC_SEL
   mov      ds,  eax

   shl      ebx, 5
   mov      ecx, [ orb_cdt + ebx + CDT.ds_sel ]            ;what selector are we freeing?

   and      ecx, 0xFFFF
   cmp      ecx, 0xFFFE
   je       short .not_cached

   ; -- the rejected ObjRef used to have a selector - free it

   mov   word  [ orb_cdt + ebx + CDT.ds_sel ], 0xFFFE
.free_selector:
   mov      eax, [ sel_free ]
   mov      [ orb_gdt + ecx ], eax                         ;to_go->next = free_list
   cmpxchg  [ sel_free ], ecx                              ;free_list = to_go, only if the free-list hasn't changed.
   jne      .free_selector

.not_cached:
   pop      ds
   pop      ebx
   pop      ecx
   retf


;======================================== LINEAR ====================================
;
; input:
;  struc FL_EL
;   .size: resd 1 ; uint
;   .next: resd 1 ; fl_el *
;  endstruc
;
;  EBX = FL_EL *  (pointer free-list of areas to claim or give back)
;  ECX = grant    ( 1 = orb claims memory, 0 = orb gives memory away )
;
; output:
;  EAX = FL_EL *
;  other registers unmodified
;
method_linear:
   push     ebx                  ;preserve EBX [3]
   push     ecx
   push     edx
   push     esi

   test     ebx, ebx
   je       short .exit                                    ;if there's no mem to claim... do nothing!

   mov      eax, ORB.DYNAMIC_SEL
   mov      ds, eax
   mov      esi, [ orb_linear ]

   test     ecx, ecx
   jz       short .give_back

.examine:
   sub      ebx, esi                                       ;convert free to local ptr
   mov      eax, [ ebx ]                                   ;get the size of the this element into EAX [4]
   cmp      eax, 8                                         ;is it 8 bytes?
   je       short .xcp_elements

   cmp      eax, TCALL_EL_size                             ;is it a t-call private stack element?
   je       short .tcall_elements

   cmp      eax, STACK_EL_size                             ;is it a stack element?
   je       short .stack_elements

   jmp      short .abort                                   ; invalid size

.stack_elements:
   sub      esp, 4                                         ;leave room on stack [5]
   push     dword stack_el_fl
   jmp      short .next_element                            ;get on with linking

.tcall_elements:
   mov      edx, ebx                                       ;store the start of this free list EDX ready for [6]
   sub      esp, 4                                         ;leave room on stack [5]
   push     dword tcall_fl

.next_element:
   lea      ecx, [ ebx + 4 ]                               ;load addr of next ptr into ECX
   mov      ebx, [ ebx + 4 ]                               ;load the actual next ptr into EBX (linear addr)

   mov      [ esp + 4 ], ebx                               ;stack next-linear [5]
   test     ebx, ebx
   je       short .link_in                                 ;if there's no more list, there's not much point continuing looking!

   sub      ebx, esi                                       ;convert to local ptr
   cmp      dword [ ebx ], eax                             ;does next point to another element of the same size? (recall size in EAX at [4])
   jne      short .link_in                                 ;if not, link what we have
   sub      [ ecx ], esi                                   ;need to convert the link from linear to ORB relative
   jmp      short .next_element                            ;otherwise, link in some more...

   ; -- If control gets here we couldn't use the elements; return em

.abort:
   lea      eax, [ ebx + esi ]            ;we couldn't munch all the list -- convert back to linear
   jmp      short .exit

.give_back:                      ;FIXME: give up some lists


.all_done:
   xor      eax, eax             ;OK, everything worked!
.exit:
   mov      ebx, [ current_comp ]
   shl      ebx, 5
   mov      ds, [ orb_cdt + ebx + CDT.ds_sel ]
   pop      esi
   pop      edx                  ;get back preserved EDX
   pop      ecx                  ;get back preserved ECX
   pop      ebx                  ;get orignal ebx back [3]
   retf

.els_split:
   push     eax                                            ;remember linear address of 'next' [5]
   push     dword xcp_fl

   ; -- Jump here to link a list into an ORB free list.
   ; ECX is local addr of last "next" pointer in list to attach
   ; EDX is local addr of first element of the list to attach [6]
   ; The local addr of the free list base is at the top of the stack
   ; The linear address of the next element is next on the stack

.link_in:
   pop      ebx                                            ;Pop free-list-base into EBX
.try_link:
   mov      eax, [ ebx ]
   mov      [ ecx ], eax
   cmpxchg  [ xcp_fl ], edx                                ;link it in (remember, start of FL put in EDX at [6])
   jne      .try_link
   pop      eax                                            ;get 'next' back into EAX [5]
   test     eax, eax                                       ;have we eaten all the memory?
   jz       .exit                                          ;if so, finished
   mov      ebx, eax
   jmp      .examine                                       ;otherwise, let's continue


.xcp_elements:

   ; -- 8-byte elements -- split them up and add them to xcp_fl

   mov      edx, ebx                                       ;Start of FL in EDX ready for [6]
.split_el:
   mov      eax, [ ebx + 4 ]                               ;EAX is linear addr of next element
   lea      ecx, [ ebx + 4 ]                               ;ECX points to middle of this element
   mov      [ ebx ], ecx                                   ;Split up the element
   test     eax, eax                                       ;Is there next element?
   jz       short .els_split
   mov      eax, ebx                                       ;look at next element
   sub      eax, esi                                       ;convert from linear addr to local pointer
   cmp      dword [ eax ], 8                               ;is it another 8-byte block?
   mov      ebx, eax
   jne      short .els_split
   sub      [ ecx ], esi                                   ;convert the next-link to a local addr
   jmp      .split_el



