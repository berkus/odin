;========================================================================================
;
; The ORB constructor
;
;========================================================================================

GLOBAL method_ctor

; global data
GLOBAL orb_cdt
GLOBAL orb_gdt
GLOBAL rev_tbl
GLOBAL cdt_fl
GLOBAL xcp_fl
GLOBAL tcall_fl
GLOBAL orb_linear
GLOBAL orb_base
GLOBAL sel_free
GLOBAL max_ref
GLOBAL active_stack
GLOBAL current_comp
GLOBAL stack_el_fl
GLOBAL static_ds_size

EXTERN build_xcp_imgs
EXTERN desc.set_entry
EXTERN desc.get_limit
EXTERN desc.get_base

%ifndef __NO_CONSOLE_COMP
EXTERN create_console_component
%endif

EXTERN text_end
EXTERN data_end
EXTERN bss_end

%define ___COMPILE_ORB_CONSOLE          ; indicate we're compiling from inside the orb
%include "orb.inc"
%include "cdt.inc"
%include "desc.inc"
%include "comp.inc"
%include "stack.inc"
%include "Console.inc"
%include "debug.inc"

%define  TEMP_STACK_SZ  0x1000

text_size equ text_end
data_size equ data_end

section .text
bits 32


; Just say 'no bootimage' and lock up
; Moving it here saves us a short jump... not much, but..
no_boot_msg: db "no bootimage"
no_boot_len equ $-no_boot_msg

no_bootstrap_err:
   mov esi, no_boot_msg
   mov edi, 0xb8000
   mov ecx, no_boot_len
.print:
   mov al, [esi]
   mov [gs:edi], al
   inc edi
   mov byte [gs:edi],'N'                                   ; attribute
   inc edi
   inc esi
   loop .print
   cli
   jmp short $


;===================================== CTOR =============================================
;
;   The ORB ctor installs itself (only the ORB knows how to do this).
;   This includes initialising the GDT, MTA, and installing its own DS.
;   Care must be taken not to overwrite meta-data/method-table of the
;   .cmp image when initialising bss data.
;   Also, need to relocate pointers to global data that are linked at
;   zero but referenced before we've loaded our DS (e.g. GDT references).
;
; Input:
;   EAX = ds
;   EBX = mem_upper
;   ECX = ORB linear address
;   EDX = ORB segment size
;   CS  = ORB segment
;   DS  = ES = GS = FS = flat32 segment
; Output: never returns
;

method_ctor:

   ; -- Convert memory in EBX to bytes

   shl ebx, 10                                             ; convert from Kb to bytes
   add ebx, 0x100000                                       ; convert from upper mem to just mem

   ; -- Move bootstrap component up in memory (before it gets overwritten by ORB variables)

   push ecx                                                ; save ORB linear

   ; move from

   mov  esi, ecx                                           ; ESI = ORB linear
   add  esi, text_size
   add  esi, data_size                                     ; ESI = where the orb ends (ORB size), from where to move the bootstrap

   ; move that much

   sub  edx, text_size
   sub  edx, data_size
   mov  ecx, edx                                           ; ECX = image size

   push ecx

   ; move to

   mov  edi, ebx
   sub  edi, ecx                                           ; EDI = top of mem - image size,  to where to move the bootstrap

   push edi

   cmp ecx, 0
   je  no_bootstrap_err                                    ; nothing to boot?

   rep movsb

   pop edi                                                 ; EDI = where bootstrap starts
   pop ebp                                                 ; EBP = bootstrap size
                                                           ; used later in setting up GDT
   ; -- Create own GDT

   pop ecx

   mov esi, ecx
   mov eax, ecx                                            ; store ORB code linear
   add esi, text_size                                      ; point to start of data area
   mov [esi+mem_total], ebx                                ; store mem_total
   mov [esi+orb_linear], esi                               ; store orb (data) linear address
   mov [esi+orb_base], eax                                 ; store orb (code) linear address

   add esi, orb_gdt                                        ; load ORB's GDT

   ; -- Initialize GDT entries
   ; EAX = selector, EBX = start linear, ECX = size, EDX = DESC attributes, ESI = GDT

   push ecx                                                ; preserve linear

   ; [1] Orb code

   mov eax, ORB.TEXT
   mov ebx, ecx
   mov ecx, text_size
   mov edx, DESC.BYTE_GRAN | DESC.XR_CODE

   call desc.set_entry

   ; [2] Orb static data (from data start to bss end)

   pop ecx
   push ecx

   mov eax, ORB.STATIC_SEL
   mov ebx, ecx
   add ebx, text_size
   mov ecx, bss_end
   mov edx, DESC.BYTE_GRAN | DESC.RW_DATA

   call desc.set_entry

   ; [3] Flat32

   mov eax, ORB.DATA32_SEL
   mov ebx, 0
   mov ecx, 0x100000
   mov edx, DESC.PAGE_GRAN | DESC.RW_DATA

   call desc.set_entry

   ; [4] Orb dynamic data

   pop ecx

   mov eax, ORB.DYNAMIC_SEL
   mov ebx, ecx
   add ebx, text_end
   mov ecx, 0x100000
   mov edx, DESC.PAGE_GRAN | DESC.RW_DATA

   call desc.set_entry

   ; [5] Video memory

   mov eax, ORB.VIDEO_SEL
   mov ebx, 0xb8000
   mov ecx, 0x1040
   mov edx, DESC.BYTE_GRAN | DESC.RW_DATA

   call desc.set_entry

   ; [6] Bootstrap comp

   mov eax, ORB.BOOTSTRAP_SEL
   mov ebx, edi
   mov ecx, ebp
   mov edx, DESC.BYTE_GRAN | DESC.RW_DATA

   call desc.set_entry

   ; Fill in GDT ptr values
   mov eax, ORB.GDT_SZ-1
   mov word  [esi], ax
   mov dword [esi+2], esi

   ; -- Activate new GDT

   lgdt [esi]

   ; -- Reload segment registers with normal ORB values

   mov eax, ORB.DYNAMIC_SEL
   mov ds, eax
   mov fs, eax
   mov eax, ORB.VIDEO_SEL
   mov es, eax
   mov gs, eax
   jmp ORB.TEXT:.reloadcs
.reloadcs:

   ; After GDT is created we can reference all ORB's data as usual

   ; -- Deactivate CRT hardware cursor

   mov dx, 0x03D4    ; port 0x3D4
   mov ax, 0x000A    ; register 0xA
   out dx, al
   inc dx            ; port 0x3D5
   mov al, 0x20      ; cursor disable flag
   out dx, al

   ; -- Bootloader might put some of its "funnies" on the screen, move 'em up

   call console__scroll_up
   call console__scroll_up

   ; -- Position cursor at bottom of screen

   mov ebx, 0
   mov edx, 24
   call console__gotoxy

   outstring orbstrings.created_gdt

   ; -- Init free selectors free list

   mov esi, rev_tbl
   mov edi, orb_gdt + ORB.LAST_STD_SEL + 8
   mov eax, ORB.LAST_STD_SEL + 8 + 8

.init_loop:                                                ;*
   ; init free list item                                   ;*
   mov [edi], eax                                          ;*
   mov [edi + 4], eax                                      ;*
                                                           ;*
   ; init rev_tbl item by the way                          ;*
   mov ebx, eax                                            ;*
   shr ebx, 3                                              ;* convert to selector for rev_tbl
   dec ebx                                                 ;*
   mov word [esi + ebx], CDT.SEL_TYPE_INVALID              ;*
                                                           ;*
   add edi, DESC_size                                      ;*
   add eax, DESC_size                                      ;*
   cmp eax, ORB.GDT_SZ * DESC_size                         ;*
   jle .init_loop                                          ;*

   mov dword [edi - DESC_size], 0                          ; mark the end of the free-list

   ; -- First few selectors map to ObjRefs directly, so update rev_tbl

   mov edi, rev_tbl
   mov ecx, CDT.LAST_STD_REF + 1
   xor eax, eax
.init_loop2:                                               ;*
   mov [edi], eax                                          ;*
   add edi, 4                                              ;*
   inc eax                                                 ;*
   loop .init_loop2                                        ;*

   ; -- Initialise stack element free-list

   mov ecx, STACK_EL.INIT_FL_SZ - 1
   mov eax, STACK_EL_size
   mul ecx
   add eax, stack_cache
   mov edx, eax
   mov [edx + STACK_EL.next_esp], dword 0                  ; mark last element
   mov [edx + STACK_EL.this_ref], dword 0                  ;

   dec ecx
   sub edx, STACK_EL_size
   ; eax=stack_cache+(ecx+1)*STACK_EL_size
   ; edx=stack_cache+ecx*STACK_EL_size

.init_loop3:                                               ;*
   mov [edx + STACK_EL.next_esp], eax                      ;*
   mov [edx + STACK_EL.this_ref], dword 0                  ;*
   sub eax, STACK_EL_size                                  ;*
   sub edx, STACK_EL_size                                  ;*
   loop .init_loop3                                        ;*

   outstring orbstrings.created_stack_fl

   ; -- Initialize xcp space free-list

   mov ecx, ORB.XCP_INIT_FL_SZ - 1
   mov eax, ecx
   shl eax, 2                                              ; *4 = *ORB.XCP_SIZE
   add eax, init_xcp_fl
   mov edx, eax
   mov [edx], dword 0                                      ; mark last element

   dec ecx
   sub edx, ORB.XCP_SIZE
   ; eax=init_xcp_fl+(ecx+1)*ORB.XCP_SIZE
   ; edx=init_xcp_fl+ecx*ORB.XCP_SIZE

.init_loop4:                                               ;*
   mov [edx], eax                                          ;*
   sub eax, ORB.XCP_SIZE                                   ;*
   sub edx, ORB.XCP_SIZE                                   ;*
   loop .init_loop4                                        ;*

   outstring orbstrings.created_xcp_fl

   ; -- Initialize the CDT

   ; Building the free-list is slightly complicated since we have
   ; FL_COUNT lists of groups of 2^n references.
   ; Each list has INIT_CDT_SZ / FL_COUNT / FLn_SIZE elements

   mov edi, orb_cdt
   mov esi, cdt_fl                                         ; current free list
   mov ecx, CDT.INIT_SIZE / CDT.FL_COUNT                   ; number of free list elements
   mov ebx, 1                                              ; start with singles

   mov eax, CDT.LAST_STD_REF + 1                           ; First few segments and CDT
   mov [esi], eax                                          ; entries are allocated statically
   sub ecx, eax                                            ; therefore we've already effectively
   inc ecx                                                 ; allocated a few 'singles'.

.init_loop5:                                               ;*
   mov word [edi + CDT.ds_sel], 0xFFFF                     ;* Invalid to start with
   mov word [edi + CDT.cs_sel], 0xFFFF                     ;* (til we say otherwise)
                                                           ;*
   mov eax, edi                                            ;*
   sub eax, orb_cdt                                        ;*
   shr eax, 5                                              ;* convert into CDT index
   add eax, ebx                                            ;* add entry size
                                                           ;*
   mov dword [edi + CDT.next], eax                         ;* build up the free-list
                                                           ;*
   dec ecx                                                 ;*
   jnz short .finish_loop5                                 ;*
                                                           ;*
   ; we've finished this free-list                         ;*
                                                           ;*
   mov dword [edi + CDT.next], 0                           ;* this list's last entry
   add esi, 4                                              ;* next cdt_fl entry
   mov [esi], eax                                          ;* start next free list space
   mov ecx, CDT.INIT_SIZE / CDT.FL_COUNT                   ;* that much entries in next fl
   shl ebx, 1                                              ;* entries are now twice larger
                                                           ;*
.finish_loop5:                                             ;*
   add edi, CDT_size                                       ;*
   cmp edi, orb_cdt + CDT.INIT_SIZE * CDT_size             ;*
   jl  .init_loop5                                         ;*

   ; -- Init ORB CDT

   ; CDT[0]
   mov edi, orb_cdt
   mov word  [edi + CDT.ds_sel], ORB.STATIC_SEL            ; mark ORB's DS -- needed when constructors return
   mov word  [edi + CDT.cs_sel], ORB.TEXT
   mov dword [edi + CDT.mcount], 0                         ; however, we don't want anyone calling any methods on the ORB

   ; CDT[2] = CDT[STATIC_REF]
   mov edi, orb_cdt + ORB.STATIC_REF * CDT_size
   mov word  [edi + CDT.ds_sel], ORB.STATIC_SEL
   mov word  [edi + CDT.cs_sel], ORB.TEXT
   mov dword [edi + CDT.mcount], 0

   ; CDT[4] = CDT[DYNAMIC_REF]
   mov edi, orb_cdt + ORB.DYNAMIC_REF * CDT_size
   mov word  [edi + CDT.ds_sel], ORB.DYNAMIC_SEL
   mov word  [edi + CDT.cs_sel], ORB.TEXT
   mov dword [edi + CDT.mcount], 0

   ; -- Init bootstrap image CDT

   xor eax, eax
   mov edi, orb_cdt + ORB.BOOTSTRAP_REF * CDT_size
   mov word  [edi + CDT.ds_sel], ORB.BOOTSTRAP_SEL
   mov word  [edi + CDT.cs_sel], ax
   mov dword [edi + CDT.mcount], eax
   mov dword [edi + CDT.call_count], eax
   mov dword [edi + CDT.gdt_lock], eax
   mov dword [edi + CDT.mtbl], eax
   mov dword [edi + CDT.type_ptr], TYPE_PTR_DATA           ; it's a null-component
   mov eax, dword [orb_gdt + ORB.BOOTSTRAP_SEL]
   mov dword [edi + CDT.descr1], eax
   mov eax, dword [orb_gdt + ORB.BOOTSTRAP_SEL + 4]
   mov dword [edi + CDT.descr2], eax

   outstring orbstrings.created_cdt

   ; -- Initialize tcall elements free list

   mov ecx, TCALL_EL.INIT_FL_SZ - 1
   mov eax, ecx
   shl eax, 4                                              ; *16 = *TCALL_EL_size
   add eax, init_tcall_fl
   mov edx, eax
   mov [edx + TCALL_EL.next], dword 0                      ; mark last element

   dec ecx
   sub edx, TCALL_EL_size
   ; eax=init_tcall_fl+(ecx+1)*TCALL_EL_size
   ; edx=init_tcall_fl+ecx*TCALL_EL_size

.init_loop6:                                               ;*
   mov [edx + TCALL_EL.next], eax                          ;*
   sub eax, TCALL_EL_size                                  ;*
   sub edx, TCALL_EL_size                                  ;*
   loop .init_loop6                                        ;*

   outstring orbstrings.created_tcall_fl

   ; -- Set up a stack in who's context we execute
   ;
   ; create the init stack in the space immediately below us

   push dword 0                                            ; resume_ctx
   push dword 0                                            ; link_to
   push dword TEMP_STACK_SZ                                ; stack size
   push dword 12                                           ; 3 parameter words
   push dword 0xA0000 - TEMP_STACK_SZ                      ; linear address
   push dword TYPE_REF_STACK                               ; type
   mov  eax, 1                                             ; 1 component to create
   METHOD_CREATE
   add  esp, 24

   ; this needs to point to free space so that when the "activate" writes out
   ; its "resume ctx" to out-going stack it goes somewhere harmless.

   mov edi, eax                                            ; edi = init_stack
   shl edi, 5                                              ; convert to CDT ptr
   mov dword [orb_cdt + edi + CDT.stack], stack_cache      ; point its stack to safe place

   ; "activate"
   mov ebx, eax                                            ; ebx = init_stack
   mov ecx, ORB.DYNAMIC_REF                                ; ecx = resume_ctx
   METHOD_SWITCH_STACKS

   ; lock stack in GDT
   ; ebx = init_stack
   METHOD_LOCK

   mov ss, eax                                             ; eax = locked selector
   mov esp, TEMP_STACK_SZ

   outstring orbstrings.created_stack
   outdwordn eax

   ; -- Print ORB startup parameters

   outstring orbstrings.orb_params
   outdword  [orb_linear]
   outstring orbstrings.comma
   mov edx, [ mem_total ]
   add edx, 0x00080000
   shr edx, 20                                             ; convert to MBytes
   outint
   outstring orbstrings.orb_params2

   ; -- Create system console component

%ifndef __NO_CONSOLE_COMP
   pause
   call create_console_component
   outstring orbstrings.created_console
   pause
%endif

   ; -- Create bootstrap component

   mov ebx, ORB.BOOTSTRAP_REF
   METHOD_INSTALL

   outstring orbstrings.created_libos

   ; -- Create ORB exceptions

   mov ecx, ORB.FIRST_XCP_IMG_SEL
   mov ebx, ORB.LAST_XCP_IMG_SEL
   call build_xcp_imgs

   ; -- Need to pre-create resource exception type and instance

   mov   eax, orb_xcp_rsc_ref
   add   eax, [ orb_linear ]                               ; EAX = linear of xcp_rsc_ref
   push  dword 0                                           ; params
   push  dword eax                                         ; where
   push  dword ORB.XCP_RSC_TYPE                            ; what
   mov   eax, 1                                            ; make just one please
   METHOD_CREATE
   add   esp, 12

   outstring orbstrings.created_xcp

   ; -- Boot library OS

   mov   edi, [mem_total]
   sub   edi, [orb_linear]
   sub   edi, COMP_DESC_size                               ; EDI = bootstrap comp_desc in ORB DS

   mov   esi, orb_gdt
   mov   eax, ORB.BOOTSTRAP_SEL
   call  desc.get_base                                     ; returns base in EBX
   call  desc.get_limit                                    ; returns limit in ECX
   inc   ecx

   ; display information about bootstrap component

   outstring orbstrings.bootcomp_is
   outdword  ecx
   outstring orbstrings.bootbytes_big_at
   outdword  ebx
   outstring orbstrings.bootcomp_desc
   outdword  [ edi + COMP_DESC.text_size ]
   outstring orbstrings.bootcomp_data
   outdword  [ edi + COMP_DESC.data_size ]
   outstring orbstrings.bootcomp_bss
   outdwordn [ edi + COMP_DESC.bss_size ]

   pause ;*****************************************************************************************

   ; create instance right below the init image

   mov   ecx, [ edi + COMP_DESC.data_size ]
   add   ecx, [ edi + COMP_DESC.bss_size  ]

   sub   ebx, ecx                                          ; EBX = DS below init image

   push  dword ebx                                         ; pass location to instance ctor
   push  dword 4                                           ; 4 bytes of params ^^
   push  dword ebx                                         ; where
   push  dword ORB.BOOTSTRAP_REF                           ; what
   mov   eax, 1                                            ; one boot comp is quite enough
   METHOD_CREATE
   add   esp, 16

   
   pause ;*****************************************************************************************
   

   ; -- LibOS boot component created - now call it's main()

   outstring orbstrings.letsgo
   outdwordn eax
   pause

   mov   ebx, eax                                          ; instance ref from call to create
   xor   ecx, ecx                                          ; method 0
   METHOD_CALL

   ; -- End of ORB session

.end_session:
   mov   esi, orbstrings.end_session
   call  console__print

   call  console__wait_ack

.wait_reboot:
   in al, 0x64
   test al, 0x02
   jnz .wait_reboot
   mov al, 0xFE
   out 0x64, al

   cli
   jmp   short $


;-------------------------------------------------------------------------
;  Initialized data
;-------------------------------------------------------------------------
section .data

current_comp: dd ORB.DYNAMIC_REF

sel_free: dd ORB.LAST_STD_SEL + 8  ; next free GDT selector  FIXME convert to sel_fl as this is free-list
max_ref:  dd CDT.LAST_STD_REF      ; the highest usable ObjRef (i.e. top index of the CDT)
cdt_size: dd CDT.INIT_SIZE         ; current CDT size

static_ds_size: dd bss_end

active_stack: dd stack_cache

; the stack cache free list head.
; FIXME: we need to support bringing stack els in and out of the cache on demand
stack_el_fl: dd stack_cache

tcall_fl:    dd init_tcall_fl

xcp_fl:      dd init_xcp_fl

orbstrings:
stringz .created_gdt,      {"[ORB] Initialized GDT",EOL}
stringz .created_stack_fl, {"[ORB] Initialized stack element free list",EOL}
stringz .created_xcp_fl,   {"[ORB] Initialized exception space free list",EOL}
stringz .created_cdt,      {"[ORB] Initialized CDT",EOL}
stringz .created_tcall_fl, {"[ORB] Initialized tcall elements free list",EOL}
stringz .created_stack,    {"[ORB] Initialized stack, selector: "}
stringz .orb_params,       {"[ORB] ORB at linear address: "}
stringz .comma,            {", "}
stringz .orb_params2,      {"MB memory",EOL}
stringz .created_console,  {"[ORB] Created internal console component",EOL,"[ORB] Installing library OS",EOL}
stringz .created_libos,    {"[ORB] Initialized bootstrap component",EOL}
stringz .created_xcp,      {"[ORB] Initialized exceptions",EOL}
stringz .bootcomp_is,      {"[ORB] Bootstrap comp is "}
stringz .bootbytes_big_at, {" bytes big, at "}
stringz .bootcomp_desc,    {" and comp_desc is:",EOL,"[ORB] text size: "}
stringz .bootcomp_data,    {"; data size: "}
stringz .bootcomp_bss,     {"; bss size: "}
stringz .letsgo,           {"[ORB] Let's Go! with boot comp instance "}
.end_session:            db "[ORB] End of session. Goodbye!  Press <Enter> to reboot.",EOL,0


;-------------------------------------------------------------------------
;  Uninitialized data
;-------------------------------------------------------------------------
section .bss

mem_total:   resd 1      ; memory size in bytes
orb_linear:  resd 1      ; orb data segment linear address
orb_base:    resd 1      ; orb code segment linear address (used when creating console component - should I waste it?)

orb_xcp_rsc_ref: resd 1  ; static storage for orb rsc exception

; the stack cache.
; FIXME: we need to support bringing stack els in and out of the cache on demand
stack_cache: resb STACK_EL.INIT_FL_SZ * STACK_EL_size

init_xcp_fl: resd ORB.XCP_INIT_FL_SZ

init_tcall_fl: resb TCALL_EL.INIT_FL_SZ * TCALL_EL_size

cdt_fl:      resd CDT.FL_COUNT

rev_tbl:     resd ORB.GDT_SZ                               ; reverse-table: indexed on a segment
                                                           ; selector, maps to a reference
orb_gdt:     resb ORB.GDT_SZ * DESC_size                   ; GDT
orb_cdt:     resb CDT.INIT_SIZE * CDT_size ; CDT is at the end of BSS to allow its growing

%include "type.inc"
