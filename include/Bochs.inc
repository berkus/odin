; Bochs debug interface
; 
; I/O debug interface
; all macros trash AX and DX

%macro BOCHS_IODBG_ENABLE 0.nolist
	mov dx, 0x8a00
	mov ax, 0x8a00
	out dx, ax
%endmacro

%macro BOCHS_IODBG_DISABLE 0.nolist
	mov dx, 0x8a00
	mov ax, 0x8aff
	out dx, ax
%endmacro

%macro BOCHS_IODBG_ITRACE_ENABLE 0.nolist
	mov dx, 0x8a00
	mov ax, 0x8ae3
	out dx, ax
%endmacro

%macro BOCHS_IODBG_ITRACE_DISABLE 0.nolist
	mov dx, 0x8a00
	mov ax, 0x8ae2
	out dx, ax
%endmacro

%macro BOCHS_IODBG_RTRACE_ENABLE 0.nolist
	mov dx, 0x8a00
	mov ax, 0x8ae5
	out dx, ax
%endmacro

%macro BOCHS_IODBG_RTRACE_DISABLE 0.nolist
	mov dx, 0x8a00
	mov ax, 0x8ae4
	out dx, ax
%endmacro

%macro BOCHS_IODBG_PROMPT 0.nolist
	mov dx, 0x8a00
	mov ax, 0x8ae0
	out dx, ax
%endmacro
