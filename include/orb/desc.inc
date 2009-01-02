; (uses John S Fine's gdtnasm.inc constants)

; Descriptor Table pointer
struc GDTP
   .limit:  resw 1
   .linear: resd 1
endstruc


;========================================================================================
;
; i386+ Segment Descriptor
;
;      15  14  13  12  11  10  9   8   7   6   5   4   3   2   1   0
;    +---------------------------------------------------------------+
;    | segment limit 15..0                                           | +0
;    +---------------------------------------------------------------+
;    | segment base  15..0                                           | +2
;    +---------------------------------------------------------------+
;    | P | D P L |S=1| 0 | E | W | A |                   base 23..16 | +4 data
;    | P | D P L |S=1| 1 | C | R | A |                   base 23..16 | +4 code
;    | P | D P L |S=0| T   Y   P   E |                   base 23..16 | +4 system
;    +---------------------------------------------------------------+
;    |                   base 31..24 | G | B | 0 | - |  limit 19..16 | +6 data
;    |                   base 31..24 | G | D | 0 | - |  limit 19..16 | +6 code
;    |                   base 31..24 | G | 0 | 0 | 0 |  limit 19..16 | +6 system
;    +---------------------------------------------------------------+
;
;    P   Present           DPL   Descriptor Privilege Level
;    S   not System         G    page Granular
;    E   Executable         B    32 Bit
;    W   Writable           D    32 bit is Default operation size
;    A   Accessed
;    C   Conforming
;    R   Readable
;
;========================================================================================


struc DESC
   .state1: resd 1
   .state2: resd 1

   ; in state1
   .LIMIT0015_MASK equ 0x0000FFFF
   .BASE0015_MASK  equ 0xFFFF0000

   ; in state2
   .BASE1623_MASK  equ 0x000000FF
   .LIMIT1619_MASK equ 0x000F0000
   .BASE2431_MASK  equ 0xFF000000
   .TYPE_MASK      equ 0x00001F00

   ; (lower of state2)
   ; Segment descriptors (not gates) may include:
   .ACC        EQU    0x100 ; Accessed (Data or Code)

   .WRITE      EQU    0x200 ; Writable (Data segments only)
   .READ       EQU    0x200 ; Readable (Code segments only)
   .BUSY       EQU    0x200 ; Busy (TSS only)

   .EXPDOWN    EQU    0x400 ; Expand down (Data segments only)
   .CONFORM    EQU    0x400 ; Conforming (Code segments only)

   ; Each descriptor should have exactly one of
   ; next 8 codes to define the type of descriptor
   .LDT    EQU   0x0200 ; LDT segment
   .TASK   EQU   0x0500 ; Task gate
   .TSS    EQU   0x0900 ; TSS
   .CALL   EQU   0x0C00 ; 386 call gate
   .INT    EQU   0x0E00 ; 386 interrupt gate
   .TRAP   EQU   0x0F00 ; 386 trap gate
   .DATA   EQU   0x1000 ; Data segment
   .CODE   EQU   0x1800 ; Code segment

   ;Descriptors may include the following as appropriate:
   .DPL3         EQU   0x6000 ; DPL3 or mask for DPL
   .DPL2         EQU   0x4000
   .DPL1         EQU   0x2000
   .DPL0         EQU   0x0000
   .PRESENT      EQU   0x8000 ; Present

   ; (upper of state2)
   .BIG        equ 0x400000   ; Default to 32 bit mode (USE32)
   .GRAN_BIT   equ 0x800000
   .BYTE_GRAN  equ 0x000000   ; Limit is in 1 byte units
   .PAGE_GRAN  equ 0x800000   ; Limit is in 4K units

   .RO_DATA       equ ( .DATA )
   .RW_DATA       equ ( .DATA | .WRITE )
   .XR_CODE       equ ( .CODE | .READ )

   .DEFAULT_DESC  equ ( .PRESENT | .BIG )
   .DEFAULT_DATA  equ ( .PRESENT | .BIG | .RW_DATA ) ; used in method_create

endstruc

struc GATE
   .state1: resd 1
   .state2: resd 1

   ; in state1
   .DEST0015_OFFS equ 0x0000FFFF
   .DEST_SEL  equ 0xFFFF0000

   ; in state2
   .DEST1631_OFFS equ 0xFFFF0000
   .WORD_COUNT    equ 0x0000001F

   .P_BIT equ 0x8000    ; in state2

endstruc
