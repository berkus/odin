;========================================================================================
;
; Locking/Unlocking
;
;========================================================================================

GLOBAL method_lock
GLOBAL method_unlock


%include "orb.inc"
%include "cdt.inc"
%include "orb_link.inc"


section .text
bits 32

;=================================== LOCK & UNLOCK  =====================================
; input:
;  EBX = ref to lock/unlock
; output:
;  EAX = locked selector
;
method_unlock:
   mov      eax, -1
   jmp      short modify_lock

method_lock:
   mov      eax, 1

modify_lock:
   push     ds
   push     ecx
   push     ebx                           ;remember ref [*]
   mov      ecx, ORB.STATIC_SEL
   mov      ds, ecx

%ifdef _DEBUG
   cmp      ebx, [ max_ref ]
   jle      short .ref_ok
   pop      ebx
   pop      ecx
   mov      edx, 0x66442200               ; HHmm.. FIXME
   jmp      throw_invalid_xcp
.ref_ok:
%endif

   shl      ebx, 5

   add      dword [ orb_cdt + ebx + CDT.gdt_lock ], eax
   dec      eax
   jnz      short .noload                                  ;no need to load selector if we're *un*locking
   mov      ax, [ orb_cdt + ebx + CDT.ds_sel ]
   cmp      ax, 0xFFFE                                     ;is the selector currently in GDT?
   jne      short .noload                                  ;if it is, we don't need to load it!
   call     load_gdt                                       ;NOTE: ebx is already pushed on stack at [*]

.noload:
   pop      ebx
   pop      ecx
   pop      ds
   retf


