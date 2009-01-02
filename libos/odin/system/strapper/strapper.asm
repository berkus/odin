;========================================================================================
;
; LibOS bootstrapper.
; Used to initialize memory manager, interrupt dispatcher and scheduler plus
; media i/o and filesystems support.
; Then it will load the rest of the system off the media or
; do some other default action.
;
;========================================================================================
GLOBAL method_ctor
GLOBAL method_dtor
GLOBAL method_run


%include "orb.inc"
%include "console.inc"
%include "debug.inc"


section .text
bits 32

method_ctor:
	CONSOLE__print ctor_str
   CONSOLE__print linear_top
   pop edx
   CONSOLE__print_dword edx
method_dtor:
   METHOD_RET


section .data

ctor_str:    db "[ODIN] Constructed libos",EOL,0
linear_top:  db "[ODIN] Top of linear free memory: ",0
