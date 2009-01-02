;-------------------------------------------------------------------------
;
; Simple console
; Supports simple console transput
;
; Assumed: ES = video memory segment
;
; Copyright (C) 2001, Stanislav Karchebny <berk@madfire.net>
; Code portions copyright Dave Poirier <instinc@users.sourceforge.net>
; Code portions copyright Phil Frost <daboy@xgs.dhs.org>
; Distributed under BSD License
;
; TODO:
; - Monochrome adapter detection
;
;-------------------------------------------------------------------------

GLOBAL console__gotoxy
GLOBAL console__scroll_up
GLOBAL console__newline
GLOBAL console__print_int
GLOBAL console__print_char
GLOBAL console__print_dword
GLOBAL console__print_word
GLOBAL console__print_byte
GLOBAL console__print
GLOBAL console__debug_showregs
GLOBAL console__debug_showstack
GLOBAL console__debug_showmem
GLOBAL console__wait_ack

%define EOL 10

section .text
bits 32

; cursor is dword located at absolute position 0xb903c
%define CON_CURSOR 0x103c

; Screen dimensions
%define LINE_PITCH 160       ; line width in bytes
%define LINE_COUNT 25

;-------------------------------------------------------------------------
; Put cursor in position EBX,EDX
;
; input:
;---------
; EBX = x
; EDX = y
;
; output:
;---------
; registers unmodified
;
; Screen position is calculated as
; (y * 160) + (x * 2) == (y << 7) + (y << 5) + (x << 1)
;
console__gotoxy:
   push eax
   push ebx
   push edx

   mov eax, edx                                            ; EAX = y
   shl eax, 7                                              ; EAX = y * 128
   shl edx, 5                                              ; EDX = y * 32
   add eax, edx                                            ; EAX = y * 160
   shl ebx, 1                                              ; EBX = x * 2
   add eax, ebx                                            ; EAX = y * 160 + x * 2

   mov [es:CON_CURSOR], eax

   pop edx
   pop ebx
   pop eax
   ret


;-------------------------------------------------------------------------
; Plot single character in cursor position.
; Will advance cursor and handle escape codes.
;
; input:
;---------
; EAX = character (in AL only)
;
; output:
;---------
; registers unmodified
;
console__print_char:
   push eax
   push edx
   push edi

   ; handle scrolling
   mov edi, [es:CON_CURSOR]
   cmp edi, LINE_PITCH * LINE_COUNT
   jb  short .no_scroll

   call console__scroll_up
   mov edi, LINE_PITCH * (LINE_COUNT - 1)

.no_scroll:
   cmp al, EOL                                             ; newline?
   jne short .just_char

   ; -- move cursor to new line and align on line start

   mov eax, edi
   add eax, LINE_PITCH      ; eax = (cursor + line pitch)
   xor edx, edx
   mov edi, LINE_PITCH
   div edi                  ; eax = (cursor + line_pitch) / line_pitch
   mul edi
   mov edi, eax             ; eax = ((cursor + line_pitch) / line_pitch) * line_pitch

   jmp short .finish

.just_char:
   stosb
   inc edi                  ; edi = edi + 2

.finish:
   mov [es:CON_CURSOR], edi ; save cursor pos back

   pop edi
   pop edx
   pop eax
   ret


;-------------------------------------------------------------------------
; Put cursor on a new line.
;
; no input
; no output
;
console__newline:
   push eax

   mov al, EOL
   call console__print_char

   pop eax
   ret


;-------------------------------------------------------------------------
; Print 8 digits hexadecimal representation of value passed in EDX
;
; input:
;---------
; EDX = value
;
; output:
;---------
; registers unmodified
;
console__print_dword:
   pushfd
   push ecx
   push edi
   push ebx
   push eax

   mov ecx, 8

.displaying:
   rol edx, 4
   mov al, dl
   and al, 0x0F
   add al, 0x90
   daa
   adc al, 0x40
   daa
   call console__print_char
   loop .displaying

   pop eax
   pop ebx
   pop edi
   pop ecx
   popfd
   ret


;------------------------------------------------------------------------------
; Print word contents of DX register.
;
; parameters:
;------------
;  DX = value to display
;
; returned values:
;-----------------
; registers unmodified
;
console__print_word:
   push edx
   xchg dh, dl                                             ; put first byte to print in dl
   call console__print_byte
   pop edx
; -- fallthrough to console__print_byte below
;   call console__print_byte
;   ret


;------------------------------------------------------------------------------
; Print byte contents of DL register.
;
; parameters:
;------------
;  dl = value to display
;
; returned values:
;-----------------
; registers unmodified
;
console__print_byte:
   pushfd
   push eax

   ; hi digit
   mov al, dl
   shr al, 4
   and al, 0x0F
   add al, 0x90
   daa
   adc al, 0x40
   daa
   call console__print_char

   ; lo digit
   mov al, dl
   and al, 0x0F
   add al, 0x90
   daa
   adc al, 0x40
   daa
   call console__print_char

   pop eax
   popfd
   ret


;-------------------------------------------------------------------------
; Print 0 terminated string at cursor position.
; Will advance cursor and handle escape codes.
;
; input:
;---------
; ESI = string offset
;
; output:
;---------
; registers unmodified
;
console__print:
   push eax
   push esi

.loop:
   mov al, byte [esi]
   cmp al, 0
   je short .done
   call console__print_char
   inc esi
   jmp short .loop
.done:

   pop esi
   pop eax
   ret


;-------------------------------------------------------------------------
; Scroll screen 1 line up.
;
; input:
;---------
; <none>
;
; output:
;---------
; registers unmodified
;
console__scroll_up:
   push eax
   push ecx
   push esi
   push edi

   xor  edi, edi                                           ; move to line 0
   mov  esi, LINE_PITCH                                    ; move from line 1
   mov  ecx, (LINE_PITCH * (LINE_COUNT-1))/4               ; move only 24 lines
   rep
        db 0x26                                            ; ES: override prefix
        movsd                                              ; move ES:ESI to ES:EDI

   mov eax, 0x07000700                                     ; clear last screen line
   mov ecx, LINE_PITCH/4
   rep stosd

   pop edi
   pop esi
   pop ecx
   pop eax
   ret


;-------------------------------------------------------------------------
; Print integer decimal value
;
; input:
;  EDX = value
;
; output:
;
;  no registers modified
;
%define DIVIDER 100000

console__print_int:
	push eax
	push ebx
	push esi

	or   edx, edx
	jnz  short .not_zero

	mov  al, '0'
	call console__print_char
	jmp  short .quit

.not_zero:
	cmp  edx, DIVIDER
	jle  short .ok

	mov  esi, int_too_big
	call console__print
	jmp  short .quit

.ok:
	or   edx, edx
	jns  short .positive

	mov  al, '-'
	call console__print_char
	neg  edx

.positive:
	mov  ebx, DIVIDER

.skip_more:
	mov  eax, edx
	xor  edx, edx
	div  ebx

	; -- this is stupid but we need to divide ebx by ten :)
	; this should be changed into something less messy, 4sure
	push eax
	push edx
	xor  edx, edx
	mov  eax, ebx
	mov  ebx, 10
	div  ebx
	mov  ebx, eax
	pop  edx
	pop  eax

	or   eax, eax
	jz   .skip_more

	; -- now print it

.print:
	add  al, '0'
	call console__print_char

	mov eax, edx
	xor edx, edx
	div ebx

	; -- this is stupid but we need to divide ebx by ten :)
	; this should be changed into something less messy, 4sure
	push eax
	push edx
	xor  edx, edx
	mov  eax, ebx
	mov  ebx, 10
	div  ebx
	mov  ebx, eax
	pop  edx
	pop  eax

	or   ebx, ebx
	jnz  .print

	; -- print last digit

	add  al, '0'
	call console__print_char

.quit:
	pop  esi
	pop  ebx
	pop  eax
	ret


;-------------------------------------------------------------------------
; Displays registers to the screen.
; Displayed registers are:
; eax,ebx,ecx,edx,esi,edi,ebp,esp
; to come: cs,ds,ss,es,fs,gs,eip,eflags
;
; out :
; NO registers modified
;
console__debug_showregs:
   pushfd
   push esi
   push edx

   mov esi, _sr_eax
   call console__print
   mov edx, eax
   call console__print_dword

   mov esi, _sr_ebx
   call console__print
   mov edx, ebx
   call console__print_dword

   mov esi, _sr_ecx
   call console__print
   mov edx, ecx
   call console__print_dword

   mov esi, _sr_edx
   call console__print
   mov edx, dword [ss:esp]
   call console__print_dword

   mov esi, _sr_esi
   call console__print
   mov edx, dword [ss:esp + 4]
   call console__print_dword

   mov esi, _sr_edi
   call console__print
   mov edx, edi
   call console__print_dword

   mov esi, _sr_ebp
   call console__print
   mov edx, ebp
   call console__print_dword

   mov esi, _sr_esp
   call console__print
   lea edx, [ esp + 16 ]                                   ; account for pushed parameters & ret addr
   call console__print_dword

   call console__newline

   pop edx
   pop esi
   popfd
   ret


;-------------------------------------------------------------------------
; Displays last 8 dwords pushed on stack.
; no regs destroyed
;
console__debug_showstack:
   pushfd
   push esi
   push edx

   mov esi, _sr_stack
   call console__print
   mov dl, 0*4
   call console__print_byte
   mov al, ' '
   call console__print_char
   mov edx, dword [ss:esp + 4*4] ; don't show return address, start with data
   call console__print_dword

   call console__print
   mov dl, 1*4
   call console__print_byte
   mov al, ' '
   call console__print_char
   mov edx, dword [ss:esp + 4*5]
   call console__print_dword

   call console__print
   mov dl, 2*4
   call console__print_byte
   mov al, ' '
   call console__print_char
   mov edx, dword [ss:esp + 4*6]
   call console__print_dword

   call console__print
   mov dl, 3*4
   call console__print_byte
   mov al, ' '
   call console__print_char
   mov edx, dword [ss:esp + 4*7]
   call console__print_dword

   call console__print
   mov dl, 4*4
   call console__print_byte
   mov al, ' '
   call console__print_char
   mov edx, dword [ss:esp + 4*8]
   call console__print_dword

   call console__print
   mov dl, 5*4
   call console__print_byte
   mov al, ' '
   call console__print_char
   mov edx, dword [ss:esp + 4*9]
   call console__print_dword

   call console__print
   mov dl, 6*4
   call console__print_byte
   mov al, ' '
   call console__print_char
   mov edx, dword [ss:esp + 4*10]
   call console__print_dword

   call console__print
   mov dl, 7*4
   call console__print_byte
   mov al, ' '
   call console__print_char
   mov edx, dword [ss:esp + 4*11]
   call console__print_dword

   call console__newline

   pop edx
   pop esi
   popfd
   ret


;------------------------------------------------------------
; Display a 256 bytes region of memory starting at ds:esi
;
console__debug_showmem:
   pushfd                                                  ; save flags
   push ecx                                                ; save trashed registers
   push edx
   push esi

   call console__newline                                   ; ensure we start from a new line

   mov ecx, 16                                             ; dump 16 lines

.out_line:
   mov edx, esi
   call console__print_dword                               ; display line starting address

   add dword [es:CON_CURSOR], 2*2                          ; skip 2 extra chars

   push ecx
   mov ecx, 8                                              ; display 8 bytes
.out_byte1:
   mov dl, [esi]
   call console__print_byte
   inc esi
   add dword [es:CON_CURSOR], 1*2
   loop .out_byte1

   add dword [es:CON_CURSOR], 1*2                          ; skip extra character

   mov ecx, 8                                              ; display 8 more bytes
.out_byte2:
   mov dl, [esi]
   call console__print_byte
   inc esi
   add dword [es:CON_CURSOR], 1*2
   loop .out_byte2
   pop ecx

   call console__newline                                   ; advance to next line
   loop .out_line

   pop esi
   pop edx
   pop ecx
   popfd
   ret

;------------------------------------------------------------------------------
; Waits until the user press and release enter, then return control.
;
; parameters:
;------------
; none
;
; returned values:
;-----------------
; registers unmodified
;
console__wait_ack:
   pushfd                                                  ; save eflags
   push eax                                                ; save eax

   ; -- mask keyboard irq

   in al, 0x21                                             ; get master pic irq mask
   push eax                                                ; save original irq mask
   or al, 0x02                                             ; mask of irq 1 - keyboard
   out 0x21, al                                            ; send it to pic

.wait_data_in:
   in al, 0x64                                             ; get keyboard status byte
   test al, 0x01                                           ; check for waiting keyboard data
   jz .wait_data_in                                        ; no data, go wait
   in al, 0x60                                             ; get data byte
   cmp al, 0x1C                                            ; is the make code enter?
   jnz .wait_data_in                                       ; nope, go wait again

.wait_data_in_release:                                     ; enter make code received, wait for break code
   in al, 0x64                                             ; get keyboard status byte
   test al, 0x01                                           ; check for waiting keyboard data
   jz .wait_data_in_release                                ; no data, go wait
   in al, 0x60                                             ; get data byte
   cmp al, 0x9C                                            ; is the break code enter?
   jnz .wait_data_in_release                               ; nope, go wait again

   pop eax                                                 ; restore original irq mask
   test al, 0x02                                           ; was irq 1 set or cleared?
   jnz short .bypass_irq_activate                          ; irq 1 was set (masked), don't touch
   in al, 0x21                                             ; get current irq mask
   and al, 0xFD                                            ; clear irq 1 mask
   out 0x21, al                                            ; send to pic
.bypass_irq_activate:
   pop eax                                                 ; restore original eax
   popfd                                                   ; restore eflags
   ret                                                     ; give control back


section .data

_sr_eax: db EOL, 'eax: ', 0
_sr_ebx: db     ' ebx: ', 0
_sr_ecx: db     ' ecx: ', 0
_sr_edx: db     ' edx: ', 0
_sr_esi: db EOL, 'esi: ', 0
_sr_edi: db     ' edi: ', 0
_sr_ebp: db     ' ebp: ', 0
_sr_esp: db     ' esp: ', 0

_sr_stack: db EOL, 'esp+', 0

int_too_big: db "*** ATTEMPT TO PRINT INT > 100,000! ***",EOL,0
