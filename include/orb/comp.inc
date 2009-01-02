
; keep in sync with ../comp.h and ../../orb/impl_xcp.asm

struc COMP_DESC
   .text_start: resd 1 ; 0x00
   .text_size:  resd 1 ; 0x04
   .data_start: resd 1 ; 0x08
   .data_size:  resd 1 ; 0x0C
   .bss_start:  resd 1 ; 0x10
   .bss_size:   resd 1 ; 0x14
   .mt_start:   resd 1 ; 0x18
   .mt_size:    resd 1 ; 0x1C
   .version:    resd 1 ; 0x20
endstruc

