;
; debug helper macros
;

%ifdef __DEBUG
EXTERN dump_cdt_entry
EXTERN dump_mt
%endif

%macro stringz 2.nolist
%1:
%ifdef __VERBOSE_STARTUP
   db %2, 0
%endif
%endmacro

%macro pause 0.nolist
%ifdef __VERBOSE_STARTUP
   call console__wait_ack
%endif
%endmacro

%macro checkpoint 1.nolist
%ifdef __VERBOSE_STARTUP
   push esi
   mov esi, cp%1
   call console__print
   call console__wait_ack
   pop esi
%endif
%endmacro

%macro outmem 1.nolist
%ifdef __VERBOSE_STARTUP
   push esi
   mov esi, %1
   call console__debug_showmem
   call console__wait_ack
   pop esi
%endif
%endmacro

%macro outstack 0.nolist
%ifdef __VERBOSE_STARTUP
   call console__debug_showstack
   call console__wait_ack
%endif
%endmacro

%macro outregs 0.nolist
%ifdef __VERBOSE_STARTUP
   call console__debug_showregs
   call console__wait_ack
%endif
%endmacro

; === STRINGS OUTPUT ===

%macro outstring 1.nolist
%ifdef __VERBOSE_STARTUP
   mov esi, %1
   call console__print
%endif
%endmacro

%macro outstringa 1.nolist
%ifdef __VERBOSE_STARTUP
   mov esi, %1
   call console__print
   call console__wait_ack
%endif
%endmacro

%macro outchar 1.nolist
%ifdef __VERBOSE_STARTUP
   mov al, %1
   call console__print_char
%endif
%endmacro

; === DWORDS OUTPUT ===

%macro outint 1.nolist
%ifdef __VERBOSE_STARTUP
   mov edx, %1
   call console__print_int
%endif
%endmacro

%macro outint 0.nolist
%ifdef __VERBOSE_STARTUP
   call console__print_int
%endif
%endmacro

%macro outdword 1.nolist
%ifdef __VERBOSE_STARTUP
   mov edx, %1
   call console__print_dword
%endif
%endmacro

%macro outdword 0.nolist
%ifdef __VERBOSE_STARTUP
   call console__print_dword
%endif
%endmacro

%macro outdwordn 1.nolist
%ifdef __VERBOSE_STARTUP
   mov edx, %1
   call console__print_dword
   call console__newline
%endif
%endmacro

%macro outdwordn 0.nolist
%ifdef __VERBOSE_STARTUP
   call console__print_dword
   call console__newline
%endif
%endmacro

; === WORDS OUTPUT ===

%macro outword 1.nolist
%ifdef __VERBOSE_STARTUP
   mov dx, %1
   call console__print_word
%endif
%endmacro

%macro outword 0.nolist
%ifdef __VERBOSE_STARTUP
   call console__print_word
%endif
%endmacro

%macro outwordn 1.nolist
%ifdef __VERBOSE_STARTUP
   mov dx, %1
   call console__print_word
   call console__newline
%endif
%endmacro

%macro outwordn 0.nolist
%ifdef __VERBOSE_STARTUP
   call console__print_word
   call console__newline
%endif
%endmacro

; === BYTES OUTPUT ===

%macro outbyte 1.nolist
%ifdef __VERBOSE_STARTUP
   mov dl, %1
   call console__print_byte
%endif
%endmacro

%macro outbyte 0.nolist
%ifdef __VERBOSE_STARTUP
   call console__print_byte
%endif
%endmacro

%macro outbyten 1.nolist
%ifdef __VERBOSE_STARTUP
   mov dl, %1
   call console__print_byte
   call console__newline
%endif
%endmacro

%macro outbyten 0.nolist
%ifdef __VERBOSE_STARTUP
   call console__print_byte
   call console__newline
%endif
%endmacro

