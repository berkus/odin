
; -- Component Descriptor Table, CDT, entry

struc CDT
   .ds_sel:             resw 1   ; 0
   .cs_sel:             resw 1   ; 2
   .type_ptr:                    ; SEL_TYPE_* (CDT-> )
   .init_ref:           resd 1   ; 4           uint
   .mtbl:                        ; 8           MT->
   .zombie_count:                ; 8           FIXME: fix references in method_destroy
   .next:               resd 1   ; 8           objref (FIXME: should next be a pointer rather than an objref?)
   .mcount:             resd 1   ; C
   .call_count:                  ; 10
   .bss_sz:                      ; 10
   .stack:              resd 1   ; 10          STACK_EL->
   .descr:                       ; 14
   .descr1:             resd 1   ; 14
   .descr2:             resd 1   ; 18
   .zombie_ref:                  ; 1C    FIXME: fix references in method_destroy
   .gdt_lock:           resd 1   ; 1C

   .SEL_TYPE_INVALID  equ 0xFFFF
   .SEL_TYPE_UNCACHED equ 0xFFFE
   .SEL_TYPE_TYPE     equ 0xFFFD
   .SEL_TYPE_ZOMBIE   equ 0xFFFC
   .SEL_TYPE_INIT_DS  equ 0xFFFB

   .INIT_SIZE         equ 0x0800

   ; there are 4 free-lists for single, double,
   ; quadruple and 8-way contiguous objrefs.
   .FL_COUNT          equ 4

   .LAST_STD_REF      equ (ORB.LAST_STD_SEL / 8)

endstruc
