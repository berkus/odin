;========================================================================================
;
; ORB structures dump helper functions
;
;========================================================================================

GLOBAL dump_cdt_entry
GLOBAL dump_mt


%define ___COMPILE_ORB_CONSOLE
%include "orb.inc"
%include "cdt.inc"
%include "mt.inc"
%include "Console.inc"


section .text
bits 32

;================================== DUMP_CDT_ENTRY ======================================
;
; Dump contents of cdt entry pointed to by ESI
;
; input:
;  ESI = cdt entry
;
; output:
;  no regs modified
;
dump_cdt_entry:
%ifdef _DEBUG
   push eax
   push edx
   push esi
   push edi

   mov edi, esi

   mov esi, cdt.head
   call console__print
   mov esi, cdt.ds_sel
   call console__print
   mov dx, [ edi + CDT.ds_sel ]
   call console__print_word

   mov esi, cdt.cs_sel
   call console__print
   mov dx, [ edi + CDT.cs_sel ]
   call console__print_word

   mov esi, cdt.type_ptr
   call console__print
   mov edx, [ edi + CDT.type_ptr ]
   call console__print_dword

   mov esi, cdt.mtbl
   call console__print
   mov edx, [ edi + CDT.mtbl ]
   call console__print_dword

   mov esi, cdt.mcount
   call console__print
   mov edx, [ edi + CDT.mcount ]
   call console__print_dword

   mov esi, cdt.stack
   call console__print
   mov edx, [ edi + CDT.stack ]
   call console__print_dword

   mov esi, cdt.descr
   call console__print
   mov edx, [ edi + CDT.descr1 ]
   call console__print_dword
   mov  al, 32
   call console__print_char
   mov edx, [ edi + CDT.descr2 ]
   call console__print_dword

   mov esi, cdt.lock_count
   call console__print
   mov edx, [ edi + CDT.gdt_lock ]
   call console__print_dword

   call console__newline
   call console__wait_ack

   pop edi
   pop esi
   pop edx
   pop eax
%endif
   ret


;======================================= DUMP_MT ========================================
;
; Dump contents of method table pointed to by ESI
;
; input:
;  ESI = mt
;
; output:
;  no regs modified
;
dump_mt:
%ifdef _DEBUG
   push eax
   push ecx
   push edx
   push esi
   push edi

   mov edi, esi

   mov esi, mt.head
   call console__print
   mov esi, mt.mcount
   call console__print
   mov edx, [ edi + MT.mcount ]
   call console__print_dword

   mov ecx, edx                                            ; save mcount for loop below

   mov esi, mt.ctor
   call console__print
   mov edx, [ edi + MT.ctor ]
   call console__print_dword

   mov esi, mt.ctor_cs
   call console__print
   mov edx, [ edi + MT.ctor_cs ]
   call console__print_dword

   mov esi, mt.dtor
   call console__print
   mov edx, [ edi + MT.dtor ]
   call console__print_dword

   mov esi, mt.dtor_cs
   call console__print
   mov edx, [ edi + MT.dtor_cs ]
   call console__print_dword

   cmp ecx, 0
   je short .no_methods

   add edi, MT.methods

.next_method:
   mov esi, mt.start
   call console__print
   mov edx, [ edi + MT_ENTRY.start ]
   call console__print_dword

   mov esi, mt.cs
   call console__print
   mov dx, [ edi + MT_ENTRY.cs ]
   call console__print_word

   add edi, MT_ENTRY_size
   loop .next_method

.no_methods:
   call console__newline
   call console__wait_ack

   pop edi
   pop esi
   pop edx
   pop ecx
   pop eax
%endif
   ret


%ifdef _DEBUG

section .data

cdt:
.head:           db EOL,"** CDT entry",0
.ds_sel:         db EOL,"ds_sel                      : ",0
.cs_sel:         db EOL,"cs_sel                      : ",0
.type_ptr:       db EOL,"type_ptr (init_ref)         : ",0
.mtbl:           db EOL,"mtbl (next)                 : ",0
.mcount:         db EOL,"mcount                      : ",0
.stack:          db EOL,"call_count (bss_sz) (stack) : ",0
.descr:          db EOL,"descr                       : ",0
.lock_count:     db EOL,"gdt_lock                    : ",0

mt:
.head:           db EOL,"** Method Table",0
.mcount:         db EOL,"mcount  : ",0
.ctor:           db EOL,"ctor    : ",0
.ctor_cs:        db EOL,"ctor_cs : ",0
.dtor:           db EOL,"dtor    : ",0
.dtor_cs:        db EOL,"dtor_cs : ",0
.start:          db EOL,"start   : ",0
.cs:             db EOL,"cs      : ",0

%endif
