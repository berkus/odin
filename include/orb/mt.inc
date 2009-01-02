
; -- Method table

struc MT
   .mcount:   resd 1 ; 0x00
   .pad:      resd 1 ; 0x04
   .ctor:     resd 1 ; 0x08
   .ctor_cs:  resd 1 ; 0x0C
   .dtor:     resd 1 ; 0x10
   .dtor_cs:  resd 1 ; 0x14
   .methods:  resd 1 ; 0x18
endstruc

; -- MT.METHODS

struc MT_ENTRY
   .start:    resd 1 ; 0x00
   .cs:       resw 1 ; 0x04
   .psize:    resw 1 ; 0x06
endstruc
