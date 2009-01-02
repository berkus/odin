;========================================================================================
;
; load_gdt helper function
;
;========================================================================================

GLOBAL load_gdt


%define __COMPILE_LOAD_GDT
%include "orb.inc"
%include "cdt.inc"
%include "mt.inc"
%include "stack.inc"
%include "orb_link.inc"
%include "type.inc"


section .data
next_reject: dd 1


section .text
bits 32

;=======================================LOAD_GDT =======================================
; sel=eax load_gdt( objref ref=stack )
;
; An internal function that caches a selector for objref ref in the
; GDT, and returns that selector.  Other selectors are rejected from
; the GDT as necessary
;
load_gdt:

   ; -- To load the GDT with a descr, find the next free slot

   push     ebx
   push     ecx
.grab_sel:
   mov      eax, [ sel_free ]
   test     eax, eax
   jz       short .reject           ;if sel_free is zero, there aren't any free ones (have to reject)
   mov      ebx, [ orb_gdt + eax ]  ;get sel_free->next
   cmpxchg  [ sel_free ], ebx       ;do sel_free = sel_free->next, ONLY if sel_free hasn't changed
   jne      .grab_sel               ;if the above failed, we'd better try again

.got_sel:

   ; -- New selector is in eax; now let's bring in the descriptor

   mov      ebx, [ esp + 12 ]          ;load in the reference
   shl      ebx, 5
   mov      ecx, [ orb_cdt + ebx + CDT.descr1 ]
   mov      [ orb_gdt + eax ], ecx
   mov      ecx, [ orb_cdt + ebx + CDT.descr2 ]
   mov      [ orb_gdt + eax + 4 ], ecx
   mov      [ orb_cdt + ebx + CDT.ds_sel ], ax

   ; -- Also, make sure we fill in the rev_tbl

   shr      ebx, 5                  ;go back from CDT index, to ObjRef
   push     eax                     ;save eax away because we return the new selector
   and      eax, 0xFFF8             ;clear out any RPL type funniness
   shr      eax, 1                  ;GDT entries are 8 bytes, rev table entries only 4 bytes.
   mov      [ rev_tbl + eax ], ebx  ;place ObjRef in the rev table
   pop      eax                     ;restore new selector into eax -- it's the return value.

   ; -- Restore state and return

   pop      ecx
   pop      ebx
   ret                        ;ok, we've loaded the GDT

.reject:

   ; -- Obviously we don't reject if cdt[ rev_tbl[ sel ] ].lock is non-zero.  Also, if it is a stack we're rejecting,
   ;    remember to set the adjacent elements in the stack chain's next/prev selectors to 0xFFFE

   mov      ebx, ORB.DYNAMIC_SEL             ;we need to switch to dynamic segment coz we're playing with method tables
   push     ds                               ;however, we want to preserve the original DS to keep caller sane [1]
   mov      ds, ebx

.find_candidate:
   mov      ebx, 1                      ;increment "next_reject" for FIFO replacement
   xadd     dword [ next_reject ], ebx
   cmp      ebx, [ max_ref ]            ;only thing is, have we gone beyond the active references?
   jl       short .no_wrap              ;if not, no problem, but...
   mov      dword [ next_reject ], 0    ;...if we have, we need to wrap round and start at the beginning.
   jmp      .find_candidate             ;Note that there is a sort of race here: if >1 threads are rejecting and wrapping
                                        ;concurrently then they might keep setting "next_reject" to zero.  However, this
                                        ;should only happen as many times as there are processors, so although performance
                                        ;will be (slightly) adversely effected in this case, it will still be correct (we
                                        ;live with this because we already know that the FIFO repl. algorithm is crap!)

.locked_down:                           ; just saving a short jump
   popfd
   jmp      short .find_candidate


.no_wrap:
   cmp      ebx, [ current_comp ]       ; don't trash caller
   je       .find_candidate
   shl      ebx, 5
   mov      eax, [ orb_cdt + ebx + CDT.ds_sel ]
   cmp      ax, CDT.SEL_TYPE_UNCACHED                                ;is it already rejected?
   je       .find_candidate                                          ;if so, can't reject the selector
   cmp      ax, CDT.SEL_TYPE_INVALID                                 ;is it an invalid reference?
   je       .find_candidate                                          ;if so, can't reject the selector
   cmp      word  [ orb_cdt + ebx + CDT.cs_sel ], CDT.SEL_TYPE_TYPE  ;is it a type?
   je       .find_candidate                                          ;if so, can't reject the selector (FIXME: yes we can -- do it!)

   pushfd
   cli
   cmp      dword [ orb_cdt + ebx + CDT.gdt_lock ], 0        ;now that we're mutually exclusive, is it locked?
   jne      short  .locked_down                                      ;if so, no use for rejection
   mov      word  [ orb_cdt + ebx + CDT.ds_sel ], CDT.SEL_TYPE_UNCACHED

   ; -- Are we rejecting a type?  If so, we need to also invalidate MT

   cmp   word  [ orb_cdt + ebx + CDT.cs_sel ], CDT.SEL_TYPE_TYPE      ;is it a type?
   jne      short .not_type                                ;if not, no need to do anything to the method table!
   push     ecx                                            ;preserve ecx (as we shouldn't destroy it generally)
   push     eax                                            ;preserve eax (as it contains the selector we've freed)
   mov      ebx, [ orb_cdt + ebx + CDT.mtbl ]              ;get the method table's address
   mov      ecx, [ ebx + MT.mcount ]                       ;get number of normal methods on this type
   add      ecx, 2                                         ;account for ctor and dtor which need invalidating too
   mov      eax, 0xFFFFFFFE                                ;place rejected code in eax (will make loop below quicker)

.invalidate_method:
   mov      [ ebx + MT.ctor + ecx * 8 + 4 ], eax           ;invalidate method
   dec      ecx                                            ;next method
   jns      .invalidate_method                     ;Did the dec wrap around?  If so, we've invalidated everything, otherwise invalidate more
   pop      eax
   pop      ecx
   jmp      short .all_done

.not_type:
   cmp   dword [ orb_cdt + ebx + CDT.type_ptr ], TYPE_PTR_STACK
   jne   short .all_done

   mov   ebx, [ orb_cdt + ebx + CDT.stack ]
   cmp   word  [ ebx + STACK_EL.prev_ss ], STACK_EL.END_OF_CHAIN
   je    short .no_prev_stack
   mov   ebx, [ ebx + STACK_EL.prev_ptr ]
   mov   word [ ebx + STACK_EL.next_ss ], CDT.SEL_TYPE_UNCACHED   ; load uncached flag for lazy selector evaluation
   mov   ebx, [ ebx + STACK_EL.next_ptr ]
.no_prev_stack:
   cmp   word [ ebx + STACK_EL.next_ss ], STACK_EL.END_OF_CHAIN
   je    short .all_done
   mov   ebx, [ ebx + STACK_EL.next_ptr ]
   mov   word [ ebx + STACK_EL.prev_ss ], STACK_EL.END_OF_CHAIN

.all_done:
   popfd
   pop      ds                   ;Restore DS to keep caller sane (saved at [1])
   and      eax, 0xFFFF
   jmp      .got_sel


