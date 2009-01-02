;========================================================================================
;
; Descriptor manipulation helpers
;
;========================================================================================

GLOBAL desc.set_entry
GLOBAL desc.get_limit
GLOBAL desc.get_base
GLOBAL desc.set_limit
GLOBAL desc.set_type


%include "desc.inc"


;====================================== SET_ENTRY ================================
; Set entry in GDT descriptor
;
; Input:
;   EAX = selector,
;   EBX = start linear,
;   ECX = size,
;   EDX = DESC attributes, either RW_DATA or RO_DATA or XR_CODE plus granularity
;   ESI = GDT linear
; Output:
;   no registers modified
;
desc.set_entry:
   push eax
   push ebx
   push ecx
   push esi

   add esi, eax                                            ; advance to selector's
                                                           ; position in GDT
   dec ecx                                                 ; convert size to limit

   ; Load attributes
   mov eax, DESC.DEFAULT_DESC
   or  eax, edx
   mov [esi+DESC.state2], eax                              ; bring in desc attributes

   ; Load limit
   mov [esi], cx                                           ; set limit 0..15
   and ecx, DESC.LIMIT1619_MASK                            ; keep limit 16..19
   and dword [esi+DESC.state2], ~DESC.LIMIT1619_MASK       ; clear limit 16..19 in desc
   or  [esi+DESC.state2], ecx                              ; set limit 16..19

   ; Load linear
   mov [esi+2], bx                                         ; set base 0..15
   shr ebx, 16
   mov [esi+4], bl                                         ; set base 16..23
   mov [esi+7], bh                                         ; set base 24..31

   pop esi
   pop ecx
   pop ebx
   pop eax
   ret


;====================================== GET_LIMIT ================================
; Get descriptor limit
;
; Input:
;   EAX = selector,
;   ESI = GDT linear
; Output:
;   ECX = limit
;
desc.get_limit:
   push esi

   add esi, eax                                            ; advance to selector's
                                                           ; position in GDT
   mov ecx, [esi+DESC.state2]                              ; get limit 16..19 and some crap
   and ecx, DESC.LIMIT1619_MASK                            ; keep limit 16..19
   mov cx,  [esi]                                          ; get limit 0..15

   pop esi
   ret


;====================================== GET_BASE ================================
; Get descriptor base
;
; Input:
;   EAX = selector,
;   ESI = GDT linear
; Output:
;   EBX = base
;
desc.get_base:
   push esi

   add esi, eax                                            ; advance to selector's
                                                           ; position in GDT
   mov bl, [esi+4]                                         ; get base 16..23
   mov bh, [esi+7]                                         ; get base 24..31
   shl ebx, 16
   mov bx, [esi+2]                                         ; get base 0..15

   pop esi
   ret


;====================================== SET_LIMIT ================================
; Set descriptor limit
;
; Input:
;   EAX = selector,
;   ECX = size,
;   ESI = GDT linear
;
desc.set_limit:
   push ecx
   push esi

   dec ecx                                                 ; convert size to limit
   add esi, eax                                            ; advance to selector's
                                                           ; position in GDT
   mov [esi], cx                                           ; set limit 0..15
   and ecx, DESC.LIMIT1619_MASK                            ; keep limit 16..19
   and dword [esi+DESC.state2], ~DESC.LIMIT1619_MASK       ; clear limit 16..19 in desc
   or  [esi+DESC.state2], ecx                              ; set limit 16..19

   pop esi
   pop ecx
   ret


;====================================== SET_TYPE ================================
; Set descriptor type
;
; Input:
;   EAX = selector,
;   EDX = type,
;   ESI = GDT linear
;
desc.set_type:
   push edx
   push esi

   add esi, eax                                            ; advance to selector's
                                                           ; position in GDT
   and dword [esi + DESC.state2], ~DESC.TYPE_MASK          ; clear type in desc
   and edx, DESC.TYPE_MASK
   or  [esi + DESC.state2], edx                            ; bring type in

   pop esi
   pop edx
   ret

