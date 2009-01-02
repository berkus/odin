;========================================================================================
;
; The ORB multiboot stub.
;
;========================================================================================
;
; The ORB requires it to be constructed in a segment containing it and
; bootstrap component exactly, and its data must be linked at zero.
; Multiboot standard is incompatible with this since the text must be
; linked at 0x100000 (1MEG) for a multiboot kernel.
; So, we have a small stub, whose text is linked at zero, but appended
; to its end is the ORB, linked at zero.
; The stub takes over the GDT, arranging a text and data segment to
; exactly match the ORB & boot component image.  The ORB itself redoes
; the GDT once more for its own linking, but since this happens only once
; who cares (boot stub memory could also be reclaimed by ORB).
;
;========================================================================================

%include "gdtnasm.inc"


org 0x100000       ; execute at 1Meg

section .text
bits 32

_start:            ; entry point

	; -- Now set up the world as the ORB expects it.

   mov   ebx, [ ebx + 8 ]        ; get mem_upper from multiboot header

   ; -- First modify CS and DS on our GDT to match ORB *EXACTLY*

   mov   dword edx, the_orb      ; Work out where the ORB and bootstrap image starts
   mov   ecx, img_end            ; Work out where the ORB and bootstrap image ends
   sub   ecx, edx                ; Work out how big the said image is
   mov   word  [ gdt + 10 ], dx  ; Modify start of CS to be at ORB's start (top bits are recorded statically in the GDT image)
   mov   word  [ gdt + 18 ], dx  ; Modify start of DS to be at ORB's start
   cmp   ecx, 0x100000           ; We need CS and DS limits to match image size exactly,
   jge   limit_err               ; => they must be < 1Meg
   mov   edx, ecx                ; Remember ORB size
   dec   ecx                     ; Convert size to limit
   mov   word  [ gdt + 8 ], cx   ; Modify lower 16 bits of CS's limit
   mov   word  [ gdt + 16 ], cx  ; Modify lower 16 bits of DS's limit

   and   ecx, 0x000F0000         ; Mask out all other than limit[16..19]

   mov   esi, [ gdt + 12 ]       ; get top 32 bits of CS's descr into esi
   and   esi, 0xFFF0FFFF         ; remove CS's limit[16..19]
   or    esi, ecx                ; bring in limit[16..19] to top 32 bits of CS's descr
   mov   [ gdt + 12 ], esi       ; move the higher bits of descriptor back

   mov   esi, [ gdt + 20 ]       ; get top 32 bits of DS's descr into esi
   and   esi, 0xFFF0FFFF         ; remove DS's limit[16..19]
   or    esi, ecx                ; bring in limit[16..19] to top 32 bits of DS's descr
   mov   [ gdt + 20 ], esi       ; move the higher bits of descriptor back

   lgdt  [gdt]                   ; Load the new GDT with CS and DS from 1M upto 4G.

   ; -- Now boot off to ORB

   mov   eax, stack - gdt
   mov   ss, eax                 ; Load the stack segment
   mov   esp, 0x10000
   mov   eax, flat - gdt         ; Load the flat32 segment
   mov   gs, eax
   mov   fs, eax
   mov   es, eax
   mov   ds, eax

   mov   eax, data - gdt         ; eax = DS for ORB constructor
                                 ; ebx = mem_upper
   mov   ecx, the_orb            ; ecx = ORB linear address
                                 ; edx = ORB size
   jmp   8:0                     ; Load the code segment, and depart


limit_msg: db "limit2big!"
limit_len equ $-limit_msg

limit_err: ;if error, print `limit2big!` and halt
	mov esi, limit_msg
	mov edi, 0xb8000
	mov ecx, limit_len
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


;-------------------------------------------------------------------------
;
; Make a baby GDT, with DS and CS from 1M to 4G.
;
; WARNING: Flat selector must have same value as ORB's DATA32_SEL selector
;
ALIGN 4
gdt   dw gdt_limit
      dd gdt
      dw 0        ; align

code     desc  0x100000, 0xFFFFF, D_CODE + D_BIG + D_BIG_LIM            ; 0x08 A code segment from 1Meg up to 4G.
data     desc  0x100000, 0xFFFFF, D_DATA + D_BIG + D_BIG_LIM + D_WRITE  ; 0x10 A data segment from 1Meg up to 4G.
flat     desc  0,        0xFFFFF, D_DATA + D_BIG + D_BIG_LIM + D_WRITE  ; 0x18 A flat 32 segment.
stack    desc  0x000000, 0x10000, D_DATA + D_BIG + D_WRITE              ; 0x20 A stack segment from 0 to 64K.

gdt_limit equ $-gdt-1


;-------------------------------------------------------------------------
;
; Multi-boot header. Must be dword aligned within image first 8 Kb.
;
ALIGN 4
%define MBOOT_MAGIC 0x1BADB002
%define MBOOT_FLAGS 0x00010002
mboot:
.magic:  dd    MBOOT_MAGIC                       ; Magic No
.flags:  dd    MBOOT_FLAGS                       ; Flags (pass memory info, loadinfo is correct)
         dd    0 - MBOOT_MAGIC - MBOOT_FLAGS     ; checksum of multiboot header
         ; loadinfo
         dd    mboot          ; physical memloc at which mboot magic is to be loaded
         dd    _start         ; physical address of .text - we're loaded at 1Meg
         dd    img_end        ; physical address of .data end
         dd    img_end        ; physical address of .bss end
         dd    _start         ; physical address of entry point

ALIGN 16


;-------------------------------------------------------------------------
;
; The ORB and LibOS image
;
the_orb:
incbin "orb.img"              ; ORB and LibOS are included one-by-one
incbin "../bin/libos.bin"     ; ORB knows its size so it can work out libos size
img_end:

