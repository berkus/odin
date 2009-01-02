;========================================================================================
;
; Mimir memory manager
;
; Structures
;
;========================================================================================

; Memory block descriptor
; 28 bytes

struc MEMBLOCK
	.size_node:       resb TERTREE_NODE_size   ; key = size
	.base_node:       resb BINTREE_NODE_size   ; key = addr

	.size             equ MEMBLOCK.size_node + TERTREE_NODE.key
	.base             equ MEMBLOCK.base_node + BINTREE_NODE.key
endstruc

; Constrain block allocation to minimum of 64 bytes with 64 byte increments,
; 64-bytes aligned.

%define MIN_BLOCK_SIZE 64
%define BLOCK_ALIGN    MIN_BLOCK_SIZE

; Memory block holder page

%define NODEPAGE_MEMBLOCK_COUNT (2048 - NODEPAGE.data) / MEMBLOCK_size  ; make up 2Kb page

struc NODEPAGE
	.next:      resd 1
	.data:      resb MEMBLOCK_size * NODEPAGE_MEMBLOCK_COUNT
endstruc


; Statistics

struc MEMSTATS
	.size:		resd 1                                      ; structure size, used for version checking
	.total:     resd 1                                      ; total memory in bytes
	.used:      resd 1                                      ; total memory allocated
	.free:      resd 1                                      ; total memory free
	                                                        ; total - used - free = internal waste
endstruc

