GLOBAL method_ctor
GLOBAL method_dtor
GLOBAL method_run
GLOBAL method_test

;EXTERN test_bintree

%include "orb.inc"
%include "Console.inc"


section .text
bits 32

method_ctor:
method_dtor:
   METHOD_RET ; console crap doesn't work yet
   mov eax, ORB.VIDEO_SEL ; needed for text output, will be eliminated when console becomes comp
   mov es, eax
   
	CONSOLE__print ctor_str
	CONSOLE__print linear_top
   pop edx
   CONSOLE__print_dword edx
   CONSOLE__newline
   METHOD_RET

method_run:
   METHOD_RET ; ditto for console crap
   mov eax, ORB.VIDEO_SEL ; needed for text output, will be eliminated when console becomes comp
   mov es, eax

	CONSOLE__print hello_world
	CONSOLE__debug_showregs
   ; call another method of us
   METHOD_GET_SELF
   mov ebx, eax         ; call self
   mov ecx, 1           ; method 1 (method_test)
   ENTER_STACK
   push dword 2         ; parameters to pass
   push dword 1
   LEAVE_STACK(2)
	METHOD_CALL

;	call test_bintree                                       ; test binary tree routines

	CONSOLE__print bye_world
   METHOD_RET

method_test:
	CONSOLE__print testing

	CONSOLE__print param
	pop edx
	CONSOLE__print_dword edx

	CONSOLE__print param
	pop edx
	CONSOLE__print_dword edx

   METHOD_RET


section .data

ctor_str:    db "[ODIN] Constructed libos",EOL,0
linear_top:  db "[ODIN] Top of linear free memory: ",0
hello_world: db "[ODIN] Hello, world!",EOL,0
bye_world:   db "[ODIN] Bye-bye, world!",EOL,0
testing:     db "[ODIN] Testing CALL parameter passing (should have received 2 params)",EOL,0
param:       db "[ODIN] param: ",0
