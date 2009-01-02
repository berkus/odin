;-------------------------------------------------------------------------
;
; Simple console
; Supports simple console transput
; Local to the ORB, will not be used after start-up.
;
; (??) Assumed: ES = video memory segment
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
GLOBAL console__log_on
GLOBAL console__log_off
GLOBAL console__hook_logger


%ifndef __NO_CONSOLE_COMP
GLOBAL create_console_component
%endif

section .text
bits 32

%define EOL 10

; cursor is dword located at absolute position 0xb903c
%define CON_CURSOR 0x103c

; Screen dimensions
%define LINE_PITCH 160                  ; line width in bytes
%define LINE_COUNT 25

ALIGN 4
console_component:                      ; start of console comp
console_text_sect:

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

;   cmp [do_log], byte 0
;   je .no_logging
;   cmp [log_hook], dword 0
;   je .no_logging

;   call [log_hook]          ; char in AL

.no_logging:
   pop edi
   pop edx
   pop eax
   ret


bochs_e9_hook:
   out 0xe9, al
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

;	call console__wait_ack

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
%define DIVIDER 1000000000

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
;FIXME: removed int_2_big check
;   cmp  edx, DIVIDER
;   jle  short .ok

;   mov  esi, int_too_big
;   call console__print
;   jmp  short .quit

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

console__hook_logger:
console__log_on:
console__log_off:
	ret

%ifndef __NO_CONSOLE_COMP

;-------------------------------------------------------------------------
;
; Simple console component instantiated by the ORB itself.
; Supports simple console transput.
;
;-------------------------------------------------------------------------

%include "orb.inc"
%include "cdt.inc"
%include "orb_link.inc"
%include "type.inc"
%include "version"
%include "debug.inc"

; the Video memory segment
vseg equ ORB.VIDEO_SEL

;-------------------------------------------------------------------------
; Put cursor in position x,y
;
; input:
;---------
; [ esp ]     = y
; [ esp + 4 ] = x
;
method_gotoxy:
   mov bx, vseg
   mov es, bx

   mov ebx, [ esp + 4 ]                                    ; EBX = X
   mov edx, [ esp ]                                        ; EDX = Y

   call console__gotoxy
method_ctor:
method_dtor:
   METHOD_RET


;-------------------------------------------------------------------------
; Plot single character in cursor position.
; Will advance cursor and handle escape codes.
;
; input:
;---------
; [ esp ] = character (low byte only)
;
method_print_char:
   mov ax, vseg
   mov es, ax
   
   mov al, [ esp ]
   call console__print_char
   METHOD_RET


;-------------------------------------------------------------------------
; Put cursor on a new line.
;
; no input
; no output
;
method_newline:
   mov ax, vseg
   mov es, ax
   
   mov al, EOL
   call console__print_char
   METHOD_RET


;-------------------------------------------------------------------------
; Print 8 digits hexadecimal representation of value
;
; input:
;---------
; [ esp ] = value
;
method_print_dword:
   mov dx, vseg
   mov es, dx
   
   mov edx, [ esp ]
   call console__print_dword
   METHOD_RET


;------------------------------------------------------------------------------
; Print hex word.
;
; parameters:
;------------
;  [ esp ] = value to display
;
method_print_word:
   mov dx, vseg
   mov es, dx
   
   mov edx, [ esp ]
   call console__print_word
   METHOD_RET


;------------------------------------------------------------------------------
; Print hex byte.
;
; parameters:
;------------
;  [ esp ] = value to display
;
method_print_byte:
   mov dx, vseg
   mov es, dx
   
   mov edx, [ esp ]
   call console__print_byte
   METHOD_RET


;-------------------------------------------------------------------------
; Print 0 terminated string at cursor position.
; Will advance cursor and handle escape codes.
;
; input:
;---------
; [ esp ] = string length
; [ esp + ... ] = string
;
method_print:
   mov ax, vseg
   mov es, ax
   
   mov eax, ss
   mov ds, eax
   lea esi, [ esp + 4 ]
   call console__print
   METHOD_RET


;-------------------------------------------------------------------------
; Scroll screen 1 line up.
;
; no input, no output.
;
method_scroll_up:
   push eax
   mov ax, vseg
   mov es, ax
   pop eax
   call console__scroll_up
   METHOD_RET


;-------------------------------------------------------------------------
; Print integer decimal value
;
; input:
;  [ esp ] = value
;
method_print_int:
   mov dx, vseg
   mov es, dx
   
   mov edx, [ esp ]
   call console__print_int
   METHOD_RET


;-------------------------------------------------------------------------
; FIXME: this needs bugging with internal ORB structures to get to the
; real register values!!!!
;
; Displays registers to the screen.
; Displayed registers are:
; eax,ebx,ecx,edx,esi,edi,ebp,esp
; to come: cs,ds,ss,es,fs,gs,eip,eflags
;
; out :
; NO registers modified
;
method_debug_showregs:
;   mov es, vseg
;   call console__debug_showregs
   METHOD_RET


;-------------------------------------------------------------------------
; FIXME: this needs bugging with internal ORB structures to get to the
; real stack values!!!!
;
; Displays last 8 dwords pushed on stack.
; no regs destroyed
;
method_debug_showstack:
;   mov es, vseg
;   call console__debug_showstack
   METHOD_RET


;-------------------------------------------------------------------------
; FIXME: this needs bugging with internal ORB structures to get to the
; real memory values!!!!
;
; Display a 256 bytes region of memory starting at ds:esi
;
method_debug_showmem:
;   mov es, vseg
;   call console__debug_showmem
   METHOD_RET


;------------------------------------------------------------------------------
; Waits until the user press and release enter, then return control.
;
; no input, no output
;
method_wait_ack:
   call console__wait_ack
   METHOD_RET

ALIGN 4 ; ORB requires sections aligned on dword boundaries (see console_data_sect also below)
console_text_sect_end:

; * Console component data segment
console_data_sect:

%else
section .data
%endif ; __NO_CONSOLE_COMP

_sr_eax: db EOL, 'eax: ', 0
_sr_ebx: db     ' ebx: ', 0
_sr_ecx: db     ' ecx: ', 0
_sr_edx: db     ' edx: ', 0
_sr_esi: db EOL, 'esi: ', 0
_sr_edi: db     ' edi: ', 0
_sr_ebp: db     ' ebp: ', 0
_sr_esp: db     ' esp: ', 0

_sr_stack: db EOL, 'esp+', 0

;FIXME: removed int_2_big check
;int_too_big: db "*** ATTEMPT TO PRINT INT > 100,000! ***",EOL,0

do_log: db 1                            ; flag if logging is enabled
log_hook: dd bochs_e9_hook              ; logger function pointer

%ifndef __NO_CONSOLE_COMP

ALIGN 4 ; align section (REQD!)
console_data_sect_end:
console_bss_sect:
console_bss_sect_end:

; Console component method table and comp_desc
%macro mt_method 2.nolist
   dd  %1 - console_text_sect                              ; method offset
   dw  0                                                   ; gap for CS
	dw  %2 * 4                                              ; sizeof params
%endmacro

ALIGN 4
console_mt_sect:
   dd    13                                                ;method count is 13
   dd    0                                                 ;pad to align
   mt_method method_ctor, 0
   mt_method method_dtor, 0
   mt_method method_gotoxy, 2
   mt_method method_scroll_up, 0
   mt_method method_newline, 0
   mt_method method_print_int, 1
   mt_method method_print_char, 1
   mt_method method_print_dword, 1
   mt_method method_print_word, 1
   mt_method method_print_byte, 1
   mt_method method_print, 0 ;??
   mt_method method_debug_showregs, 0
   mt_method method_debug_showstack, 0
   mt_method method_debug_showmem, 0
   mt_method method_wait_ack, 0
console_mt_sect_end:

console_comp_desc:
.sect_descr:
.text_st: dd     console_text_sect     - console_component
.text_sz: dd     console_text_sect_end - console_text_sect
.data_st: dd     console_data_sect     - console_component
.data_sz: dd     console_data_sect_end - console_data_sect
.bss_st:  dd     console_bss_sect      - console_component
.bss_sz:  dd     console_bss_sect_end  - console_bss_sect
.mt_st:   dd     console_mt_sect       - console_component
.mt_sz:   dd     console_mt_sect_end   - console_mt_sect
.version: dd    __odin_VERSION
console_comp_desc_end: ; these shouldn't be aligned, cause comp_desc is from accessed from very section end
console_component_end:

console_component_limit equ console_component_end - console_component - 1

;;section .text ; we're in .text already

%include "Bochs.inc"

;============================= CREATE_CONSOLE_COMPONENT =================================
;
; Installer for ORB internal console component.
;
create_console_component:

	outstring cr_enter
   pause

   mov     eax, console_component
   add     eax, [ orb_base ]                               ; linear address of our img in EAX

   ; -- Build descriptor

   outstring cr_descr
   outdword  eax
   outstring cr_limit
   outdword  console_component_limit
   pause
	
   lea   edx, [ orb_gdt + ORB.CONSOLE_SEL ]                ; load descriptor ptr
   mov   word  [ edx ], console_component_limit            ; set descriptor's limit
   mov   [ edx + 2 ], ax                                   ; put low word of base into descr
   mov   dword [ edx + 4 ], 0x00409200                     ; mark top of descr with invariant bits
   shr   eax, 16                                           ; get base[16..31]
   mov   [ edx + 4 ], al                                   ; put base[16..23] into descr
   mov   [ edx + 7 ], ah                                   ; put base[24..31] into descr

   ; -- Build CDT entry

   outstring cr_mkcdt
   pause

   lea   eax, [ orb_cdt + ORB.CONSOLE_REF * CDT_size ]     ; load cdt ptr
   xor   edx, edx
   mov   word  [ eax + CDT.ds_sel ], ORB.CONSOLE_SEL       ; set selector
   mov   word  [ eax + CDT.cs_sel ], dx                    ; null type has no CS
   mov   dword [ eax + CDT.type_ptr ], TYPE_PTR_DATA       ; null type
   mov   dword [ eax + CDT.gdt_lock ], edx                 ; zero GDT lock
   mov   dword [ eax + CDT.mcount ], edx                   ; null types have no methods
   mov   dword [ eax + CDT.call_count ], edx               ; zero call count
   mov   dword [ eax + CDT.mtbl ], edx                     ; no method table
   mov   edx,  [ orb_gdt + ORB.CONSOLE_SEL ]               ; get bottom dword of descr into edx and...
   mov   [ eax + CDT.descr1 ], edx                         ; ...place it in CDT descr bottom
   mov   edx,  [ orb_gdt + ORB.CONSOLE_SEL + 4 ]           ; get top dword of descr into edx and...
   mov   [ eax + CDT.descr2 ], edx                         ; ...place it in CDT descr top

   ; -- Install the type

   outstring cr_instl
   pause

   mov   ebx, ORB.CONSOLE_REF                              ; gonna install the ref in EBX
   mov   dword [ rev_tbl + ORB.CONSOLE_REF * 4 ], ebx
   push  dword [ current_comp ]
   mov   dword [ current_comp ], 0
   METHOD_INSTALL                                          ; well, install it then!
   pop   dword [ current_comp ]

   ; -- Create the instance

   outstring cr_creat
   pause

   mov   eax, console_data_sect                            ; create it right where it is now!
   add   eax, [ orb_base ]                                 ; offset from ORB base (the very start)

   push  dword eax                                         ; DUMMY! ** FIXME
   push  dword 4                                           ; params
   push  dword eax                                         ; where
   push  dword ORB.CONSOLE_REF                             ; what
   mov   eax, 1                                            ; make just one please
   METHOD_CREATE
   add   esp, 16

   outstring cr_done
   pause

   ret

section .data
stringz cr_enter, {"[CON] Entered",EOL}
stringz cr_descr, {"[CON] Building descriptor",EOL,"[CON] Linear "}
stringz cr_limit, {", limit "}
stringz cr_mkcdt, {EOL,"[CON] Building CDT entry",EOL}
stringz cr_instl, {"[CON] Installing",EOL}
stringz cr_creat, {"[CON] Creating instance",EOL}
stringz cr_done,  {"[CON] Completed!",EOL}
stringz cr_yipes, {"[CON] Yipes!",EOL}

%endif

