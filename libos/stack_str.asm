section .text
bits 32

GLOBAL stack_str

;--------------------------------------------------------------------------
; -- Routine to copy a string onto the stack.
;
; Input: EAX = string
; Output: EAX, EBX, ECX trashed, ESP changed
;         stack: -------------
;         |       [size]
;         |        stri
;         v        ng0p    <- esp
;      bottom
;
stack_str:
	mov		ebx, eax		                                   ; original char* -> ebx
.copy_char:	
	mov	byte	cl, [ eax ]		                             ; get a single byte from the string
	dec	esp
	mov	byte    [ esp ], cl		                          ; push it onto the stack

	test	byte	[ eax ], 0xFF		                          ; is byte zero?
	jz		short .done

	inc	eax			                                      ; look at next char from the string
	jmp	short .copy_char                                  ; go around again

.done:	
   sub      eax, ebx                                       ; len -> eax
	xchg		[ esp + eax ], eax	                          ; clobber return address with len,
	                                                        ; but save ret addr in eax
	and		esp, -4			                                ; round esp to nearest word boundary
	push		eax			                                   ; push the return address
	ret					                                      ; back to from whence we came
	                                                        ; (only esp is different now)
