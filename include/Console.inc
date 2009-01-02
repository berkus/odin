%define EOL 10   ; \n character

%ifdef ___COMPILE_ORB_CONSOLE


EXTERN console__gotoxy
EXTERN console__scroll_up
EXTERN console__newline
EXTERN console__print_int
EXTERN console__print_char
EXTERN console__print_dword
EXTERN console__print_word
EXTERN console__print_byte
EXTERN console__print
EXTERN console__debug_showregs
EXTERN console__debug_showstack
EXTERN console__debug_showmem
EXTERN console__wait_ack
EXTERN console__log_on
EXTERN console__log_off
EXTERN console__hook_logger


%macro CONSOLE__gotoxy 2.nolist ; X,Y
   mov ebx, %1
   mov edx, %2
   call console__gotoxy
%endmacro

%macro CONSOLE__scroll_up 0.nolist
   call console__scroll_up
%endmacro

%macro CONSOLE__newline 0.nolist
   call console__newline
%endmacro

%macro CONSOLE__print_int 1.nolist ; int
   mov edx, %1
   call console__print_int
%endmacro

%macro CONSOLE__print_char 1.nolist
   mov al, %1
   call console__print_char
%endmacro

%macro CONSOLE__print_dword 1.nolist
   mov edx, %1
   call console__print_dword
%endmacro

%macro CONSOLE__print_word 1.nolist
   mov dx, %1
   call console__print_word
%endmacro

%macro CONSOLE__print_byte 1.nolist
   mov dl, %1
   call console__print_byte
%endmacro

%macro CONSOLE__print 1.nolist
   mov esi, %1
   call console__print
%endmacro

%macro CONSOLE__debug_showregs 0.nolist
   call console__debug_showregs
   call console__wait_ack
%endmacro

%macro CONSOLE__debug_showstack 0.nolist
   call console__debug_showstack
   call console__wait_ack
%endmacro

%macro CONSOLE__debug_showmem 0.nolist
   call console__debug_showmem
   call console__wait_ack
%endmacro

%macro CONSOLE__wait_ack 0.nolist
   call console__wait_ack
%endmacro

%macro CONSOLE__logging_on 0.nolist
   call console__log_on
%endmacro

%macro CONSOLE__logging_off 0.nolist
   call console__log_off
%endmacro


%else ; ___COMPILE_ORB_CONSOLE


; Component methods
; (TODO: incgen should generate those together with the macros!!!)

%define CONSOLE_gotoxy           0
%define CONSOLE_scroll_up        1
%define CONSOLE_newline          2
%define CONSOLE_print_int        3
%define CONSOLE_print_char       4
%define CONSOLE_print_dword      5
%define CONSOLE_print_word       6
%define CONSOLE_print_byte       7
%define CONSOLE_print            8
%define CONSOLE_debug_showregs   9
%define CONSOLE_debug_showstack  10
%define CONSOLE_debug_showmem    11
%define CONSOLE_wait_ack         12
%define CONSOLE_logging_on       13
%define CONSOLE_logging_off      14
%define CONSOLE_hook_logger      15

EXTERN stack_str


%macro CONSOLE__gotoxy 2.nolist ; X,Y
	ENTER_STACK
	push dword %1
	push dword %2
	LEAVE_STACK(2)
	mov  ebx, ORB.CONSOLE_REF
	mov  ecx, CONSOLE_gotoxy
	METHOD_CALL
%endmacro

%macro CONSOLE__scroll_up 0.nolist
	mov  ebx, ORB.CONSOLE_REF
	mov  ecx, CONSOLE_scroll_up
	METHOD_CALL
%endmacro

%macro CONSOLE__newline 0.nolist
	mov  ebx, ORB.CONSOLE_REF
	mov  ecx, CONSOLE_newline
	METHOD_CALL
%endmacro

%macro CONSOLE__print_int 1.nolist ; int
	ENTER_STACK
	push dword %1
	LEAVE_STACK(1)
	mov  ebx, ORB.CONSOLE_REF
	mov  ecx, CONSOLE_print_int
	METHOD_CALL
%endmacro

%macro CONSOLE__print_char 1.nolist
	ENTER_STACK
	push dword %1
	LEAVE_STACK(1)
	mov  ebx, ORB.CONSOLE_REF
	mov  ecx, CONSOLE_print_char
	METHOD_CALL
%endmacro

%macro CONSOLE__print_dword 1.nolist
	ENTER_STACK
	push dword %1
	LEAVE_STACK(1)
	mov  ebx, ORB.CONSOLE_REF
	mov  ecx, CONSOLE_print_dword
	METHOD_CALL
%endmacro

%macro CONSOLE__print_word 1.nolist
	ENTER_STACK
	push dword %1
	LEAVE_STACK(1)
	mov  ebx, ORB.CONSOLE_REF
	mov  ecx, CONSOLE_print_word
	METHOD_CALL
%endmacro

%macro CONSOLE__print_byte 1.nolist
	ENTER_STACK
	push dword %1
	LEAVE_STACK(1)
	mov  ebx, ORB.CONSOLE_REF
	mov  ecx, CONSOLE_print_byte
	METHOD_CALL
%endmacro

%macro CONSOLE__print 1.nolist
	ENTER_STACK_STR
	mov  eax, %1
	call stack_str
	LEAVE_STACK_STR
	mov  ebx, ORB.CONSOLE_REF
	mov  ecx, CONSOLE_print
	METHOD_CALL
%endmacro

%macro CONSOLE__debug_showregs 0.nolist
	mov  ebx, ORB.CONSOLE_REF
	mov  ecx, CONSOLE_debug_showregs
	METHOD_CALL
%endmacro

%macro CONSOLE__debug_showstack 0.nolist
	mov  ebx, ORB.CONSOLE_REF
	mov  ecx, CONSOLE_debug_showstack
	METHOD_CALL
%endmacro

%macro CONSOLE__debug_showmem 0.nolist
	mov  ebx, ORB.CONSOLE_REF
	mov  ecx, CONSOLE_debug_showmem
	METHOD_CALL
%endmacro

%macro CONSOLE__wait_ack 0.nolist
	mov  ebx, ORB.CONSOLE_REF
	mov  ecx, CONSOLE_wait_ack
	METHOD_CALL
%endmacro

%macro CONSOLE__logging_on 0.nolist
	mov  ebx, ORB.CONSOLE_REF
	mov  ecx, CONSOLE_logging_on
	METHOD_CALL
%endmacro

%macro CONSOLE__logging_off 0.nolist
	mov  ebx, ORB.CONSOLE_REF
	mov  ecx, CONSOLE_logging_off
	METHOD_CALL
%endmacro

; this needs work: need to determine what parameters to pass
;%macro CONSOLE__hook_logger 2(1?).nolist
;	mov  ebx, ORB.CONSOLE_REF
;	mov  ecx, CONSOLE_hook_logger
;	METHOD_CALL
;%endmacro


%endif ; ___COMPILE_ORB_CONSOLE
