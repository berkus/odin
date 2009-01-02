;========================================================================================
;
; Type uninstallation
;
;========================================================================================

GLOBAL method_uninstall


%include "orb.inc"
%include "cdt.inc"
%include "orb_link.inc"


section .text
bits 32

;=============================  UNINSTALL  =======================================
; Uninstallation is pretty simple: just free the selector and the reference
; Note that the uninstall/create race is dellegated to the library OS to deal with
;
; input:
;  EBX = objref to uninstall
;
method_uninstall:
   push     ds
   push     ecx
   mov      eax, ORB.STATIC_SEL
   mov      ds, eax

%ifdef _DEBUG
   cmp      ebx, [ max_ref ]
   jg       short .invalid_ref
%endif

   shl      ebx, 5
   add      ebx, orb_cdt

%ifdef _DEBUG
   cmp   word  [ ebx + CDT.cs_sel ], CDT.SEL_TYPE_TYPE  ;make sure it's a proper type we're uninstalling
   jne      short .error
%endif

   inc      dword [ ebx + CDT.gdt_lock ]                   ;Prevent race with GDT-reject
   xor      ecx, ecx
   mov      cx, [ ebx + CDT.ds_sel ]
   cmp      cx, CDT.SEL_TYPE_UNCACHED
   je       short .not_cached

.free_sel:
   mov   dword [ ebx + CDT.ds_sel ], 0xFFFFFFFF            ;the reference is now invalid
   mov      eax, [ sel_free ]                    ;find the base of the selector free-list
   mov      [ orb_gdt + ecx ], eax                   ;point the element we're freeing at the selector free-list
   cmpxchg     [ sel_free ], ecx                    ;and attempt to point free-list at freed element ATOMICALLY
   jne      .free_sel                        ;if we didn't manage to do it atomically, we'd better try again!

.not_cached:

   ; -- OK, We've freed the selector - now free the referenece

   mov      ecx, ebx
   sub      ecx, orb_cdt
   shr      ecx, 5

.link_fl_el:
   mov      eax, [ cdt_fl ]                   ;get the free-list base-> eax (note types always in the singleton reference range)
   mov      [ ebx + CDT.next ], eax           ;link the free-list into this reference
   cmpxchg  [ cdt_fl ], ecx                   ;attempt to link this reference into the free list
   jnz      .link_fl_el                       ;if the free-list base changed, we'd better try again...

   ; -- All done; let's get out of here

   pop      ecx
   pop      ds
   retf

%ifdef _DEBUG
.error:
   add      esp, 8
   jmp      throw_invalid_xcp


.invalid_ref:
   add      esp, 8
   mov      ecx, ORB.XCP_NOREF_TYPE
   jmp      throw_fatal_xcp
%endif
