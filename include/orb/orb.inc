
; -- The ORB

struc ORB
   ; -- Methods
   .CTOR           equ 0x00
   .CALL           equ 0x08
   .FCALL          equ 0x10
   .TCALL          equ 0x18
   .XFER           equ 0x20
   .CREATE         equ 0x28
   .DESTROY        equ 0x30
   .INSTALL        equ 0x38
   .UNINSTALL      equ 0x40
   .LOCK           equ 0x48
   .UNLOCK         equ 0x50
   .GET_STACK      equ 0x58
   .SEL2REF        equ 0x60
   .GET_SELF       equ 0x68
   .GET_TYPE       equ 0x70
   .SET_TYPE       equ 0x78
   .SET_DESC       equ 0x80
   .LINEAR         equ 0x88
   .FAULT          equ 0x90
   .REJECT         equ 0x98
   .SWITCH_STACKS  equ 0xA0
   .THROW          equ 0xA8
   .RET            equ 0xB0

   ; -- Selectors
   .GDT_SZ            equ 8192

   .TEXT              equ 0x08
   .STATIC_SEL        equ 0x10
   .DATA32_SEL        equ 0x18
   .DYNAMIC_SEL       equ 0x20
   .VIDEO_SEL         equ 0x28
   .BOOTSTRAP_SEL     equ 0x30
   .CONSOLE_SEL       equ 0x38
   .STACK_SEL         equ 0x40
   .FIRST_XCP_IMG_SEL equ 0x48

;   .VALID_SELECTOR_MASK equ 0xFFF8
	.HIGHEST_VALID_SELECTOR equ 0xFFF8

   ; -- Refs
   .STATIC_REF        equ ( .STATIC_SEL    / 8 )
   .DYNAMIC_REF       equ ( .DYNAMIC_SEL   / 8 )
   .BOOTSTRAP_REF     equ ( .BOOTSTRAP_SEL / 8 )
   .CONSOLE_REF       equ ( .CONSOLE_SEL   / 8 )

   ; -- Exceptions
   .XCP_INT_VEC       equ 0x30
   .XCP_RSC_COMP      equ 0x12
   .XCP_TYPE_COUNT    equ 7

   .XCP_RSC_TYPE      equ ( .FIRST_XCP_IMG_SEL / 8 + 0 )
   .XCP_INVALID_TYPE  equ ( .FIRST_XCP_IMG_SEL / 8 + 1 )
   .XCP_NOREF_TYPE    equ ( .FIRST_XCP_IMG_SEL / 8 + 2 )
   .XCP_NOMEM_TYPE    equ ( .FIRST_XCP_IMG_SEL / 8 + 3 )
   .XCP_NOSTACK_TYPE  equ ( .FIRST_XCP_IMG_SEL / 8 + 4 )
   .XCP_NORET_TYPE    equ ( .FIRST_XCP_IMG_SEL / 8 + 5 )
   .XCP_ZOMBIE_TYPE   equ ( .FIRST_XCP_IMG_SEL / 8 + 6 )

   .LAST_XCP_IMG_SEL  equ ( .FIRST_XCP_IMG_SEL + ( .XCP_TYPE_COUNT - 1 ) * 8 )
   .LAST_STD_SEL      equ .LAST_XCP_IMG_SEL

   .XCP_STACK         equ 1 ;???

   .XCP_SIZE          equ 4
   .XCP_INIT_FL_SZ    equ 10

   ; -- Misc

	.STACK_BUF         equ 24   ; for calling via ORB.CALL, see ENTER_STACK below for comments
	.MAX_FL_NUMBER     equ 4

endstruc

; For calling methods that take parameters we must step over ORB's method_call internal
; variables. The ORB.STACK_BUF equals size of these parameters.
; However, to simplify life a bit I provide two simple macros that you should use when
; calling such methods;
; The first one, ENTER_STACK, prepares stack for pushing call parameters.

%macro ENTER_STACK 0.nolist
	sub esp, ORB.STACK_BUF
%endmacro

%macro ENTER_STACK_STR 0.nolist
	mov ebp, esp
	sub esp, ORB.STACK_BUF
%endmacro

; The second one LEAVE_STACK(params) rewinds stack back ready for call.
; params parameter is count of dword parameters to leave on stack.

%macro LEAVE_STACK 1.nolist
	add esp, ORB.STACK_BUF + 4 * %1
%endmacro

%macro LEAVE_STACK_STR 0.nolist
	mov esp, ebp
%endmacro


;========================= shortcuts for ORB methods calls ==============================
; they both save you alot of typing and hide either jmp or call is made to call method

%macro METHOD_CALL 0.nolist
   call ORB.CALL : ORB.CALL
%endmacro

%macro METHOD_FCALL 0.nolist
   call ORB.CALL : ORB.FCALL
%endmacro

%macro METHOD_TCALL 0.nolist
   call ORB.CALL : ORB.TCALL
%endmacro

%macro METHOD_XFER 0.nolist
   jmp ORB.CALL : ORB.XFER
%endmacro

%macro METHOD_CREATE 0.nolist
   call ORB.CALL : ORB.CREATE
%endmacro

%macro METHOD_DESTROY 0.nolist
   call ORB.CALL : ORB.DESTROY
%endmacro

%macro METHOD_INSTALL 0.nolist
   call ORB.CALL : ORB.INSTALL
%endmacro

%macro METHOD_UNINSTALL 0.nolist
   call ORB.CALL : ORB.UNINSTALL
%endmacro

%macro METHOD_LOCK 0.nolist
   call ORB.CALL : ORB.LOCK
%endmacro

%macro METHOD_UNLOCK 0.nolist
   call ORB.CALL : ORB.UNLOCK
%endmacro

%macro METHOD_GET_STACK 0.nolist
   call ORB.CALL : ORB.GET_STACK
%endmacro

%macro METHOD_SEL2REF 0.nolist
   call ORB.CALL : ORB.SEL2REF
%endmacro

%macro METHOD_GET_SELF 0.nolist
   call ORB.CALL : ORB.GET_SELF
%endmacro

%macro METHOD_GET_TYPE 0.nolist
   call ORB.CALL : ORB.GET_TYPE
%endmacro

%macro METHOD_SET_TYPE 0.nolist
   call ORB.CALL : ORB.SET_TYPE
%endmacro

%macro METHOD_SET_DESC 0.nolist
   call ORB.CALL : ORB.SET_DESC
%endmacro

%macro METHOD_LINEAR 0.nolist
   call ORB.CALL : ORB.LINEAR
%endmacro

%macro METHOD_FAULT 0.nolist
   call ORB.CALL : ORB.FAULT
%endmacro

%macro METHOD_REJECT 0.nolist
   call ORB.CALL : ORB.REJECT
%endmacro

%macro METHOD_SWITCH_STACKS 0.nolist
   call ORB.CALL : ORB.SWITCH_STACKS
%endmacro

%macro METHOD_THROW 0.nolist
   call ORB.CALL : ORB.THROW ;FIXME should be jmp like for RET
%endmacro

%macro METHOD_RET 0.nolist
   jmp ORB.CALL : ORB.RET
%endmacro
