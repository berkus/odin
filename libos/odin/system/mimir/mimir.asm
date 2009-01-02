;========================================================================================
;
; Mimir memory manager.
;
; Copyright (C) 2001, Stanislav Karchebny <berk@madfire.net>
; Distributed under BSD License.
;
; History bits:
; Mimir  Norse god of memory and ultimate wisdom. He exacted from Odin his
;        right eye as the price of drinking from the well to gain wisdom.
;
;========================================================================================

GLOBAL method_ctor
GLOBAL method_dtor
GLOBAL method_create
GLOBAL method_create_at
GLOBAL method_destroy
GLOBAL method_install
GLOBAL method_uninstall
GLOBAL method_get_addr
GLOBAL method_linear
GLOBAL method_get_statistics

;EXTERN data_end
;EXTERN bss_end


%include "orb.inc"
%include "bintree.inc"
%include "tertree.inc"
%include "mimir.inc"
%include "console.inc"
%include "debug.inc"


section .text
bits 32

; Binary tree manipulation

;find_bnode: mbintree__find_node ebx, edi, esi,
;                                MEMBLOCK.base_node + BINTREE_NODE.key,
;                                MEMBLOCK.base_node + BINTREE_NODE.less,
;                                MEMBLOCK.base_node + BINTREE_NODE.greater
;binsert:    mbintree__insert_node
;bremove:    mbintree__remove_node

;========================================================================================
; Mimir constructor.
; Initialize pre-allocated node free list, init statistics information.
;
; input:
;   [ esp ] = top of linear memory (maximum available address)
;
method_ctor:

	; -- Init nodepage free list

	mov edi, nodepage
	call init_fl

	; -- Init memory statistics

	mov edi, stats
	mov eax, [ esp ]                                        ; total memory
	mov [ edi + MEMSTATS.total ], eax
	mov [ edi + MEMSTATS.free  ], eax                       ; all memory is free

	CONSOLE__print created_mimir

method_dtor:
	METHOD_RET


;========================================================================================
; Internal function to initialize new node page free list.
;
; input:
;   EDI = nodepage address
;
; output:
;   ECX, EDI trashed
;
init_fl:
	mov dword [ edi + NODEPAGE.next ], 0                    ; there's no next page yet

	add edi, NODEPAGE.data
	mov ecx, NODEPAGE_MEMBLOCK_COUNT - 1                    ; traverse all but last nodes

.fill_fl:
	add   edi, MEMBLOCK_size
	mov   [ edi - MEMBLOCK_size ], edi
	loop  .fill_fl

	mov [ edi ], dword 0                                    ; terminate list
	ret


;========================================================================================
; Internal function to actually allocate memory.
;
; input:
;   EBX = amount of memory to allocate
;   EBP = 0 for normal allocation,
;         address of node for call from allocate_node.
;
; output:
;   ESI = node of allocated memory block
;         or 0 on failure (or set CF?)
;   EBP = 0 on normal allocation and in case provided node was consumed,
;         node address otherwise (node should be returned to free-list).
;
; -------------------------------------------------------------------
;
; Algorithm A: Allocate memory
; Input:
;    S = size to allocate
; A1. [find appropriate size]
;     P := tertree__find_ae_node(S, FSIZE);
;     if P = /\, goto A6          (FIXME: add defrag-on-demand here, A4)
;     if P.size = S, goto A3
;     if P.size > S, goto A2
; A2. [split block]
;     tertree__remove_node(P, FSIZE)
;     bintree__remove_node(P, FBASE)
;     NEW := allocate_node(NODE_FL)
;     NEW.size := S
;     NEW.base := P.base
;     P.base := P.base + S
;     P.size := P.size - S
;     tertree__insert_node(P, FSIZE)
;     bintree__insert_node(P, FBASE)
;     bintree__insert_node(NEW, UBASE)
;     goto A5
; A3. [exact alloc]
;     tertree__remove_node(P, FSIZE)
;     bintree__remove_node(P, FBASE)
;     NEW <- P
;     bintree__insert_node(P, UBASE)
;     goto A5
; A4. [defragment adjacent blocks]
; A5. [success] Output: NEW allocated node
; A6. [failure] no memory free, Output: /\
;
;
allocate_memory:

	; -- align size on 64 byte boundary

	add ebx, 63
	and ebx, -64

	; -- find appropriate size block of free memory

	mov  edi, fsize                                         ; look in size-sorted tree
	call tertree__find_ae_node
	jc   short .afailed                                     ; not found - no memory then

	cmp  ebx, [ edi + MEMBLOCK.size ]
	je   short .exact_alloc

	; -- found block is larger than we requested, split it up into two

	; first, unlink found node from both base and size free trees
	mov ebx, [ edi + MEMBLOCK.size ]
	mov edi, fsize
	call tertree__remove_node
	mov ebx, [ edi + MEMBLOCK.base ]
	mov edi, fbase
	call bintree__remove_node

	; check to see if we were provided with "extra" block from allocate_node
	test ebp, ebp
	jnz short .allocated_block

	call allocate_node
	mov  ebp, eax

.allocated_block:

	mov eax, [ esi + MEMBLOCK.base ]
	mov [ ebp + MEMBLOCK.base ], eax                        ; NEW.base = P.base
	mov [ ebp + MEMBLOCK.size ], ebx                        ; NEW.size = S
	add [ esi + MEMBLOCK.base ], ebx                        ; P.base += S
	sub [ esi + MEMBLOCK.size ], ebx                        ; P.size -= S

	; return P to free tree
	mov  edi, fsize
	call tertree__insert_node
	mov  edi, fbase
	call bintree__insert_node

	; insert NEW into allocated tree
	mov esi, ebp
	mov edi, ubase
	call bintree__insert_node

	xor ebp, ebp                                            ; we've consumed the node
	jmp short .allok

	; -- we've found block exactly the size we want

.exact_alloc:

	; COMBINE THIS WITH THE ABOVE - THE SAME CODE
	; first, unlink found node from both base and size free trees
	mov ebx, [ edi + MEMBLOCK.size ]
	mov edi, fsize
	call tertree__remove_node
	mov ebx, [ edi + MEMBLOCK.base ]
	mov edi, fbase
	call bintree__remove_node

	; insert NEW into allocated tree
	mov edi, ubase
	call bintree__insert_node

.allok:
	ret

.afailed:
	xor esi, esi
	ret


;========================================================================================
; Get a node from node free list. If free list exhausted, allocate extra free space.
;
; input:
;  nothing
;
; output:
;  EAX = new node
;
; -------------------------------------------------------------------
;
; Algorithm N: Allocate node from node free-list.
; N1. P <- FreeList
;     if P.next = /\, goto N3
;     goto N2
; N2. FreeList <- P.next
;     return P
; N3. Q := allocate new page
;     page.next_page := Q
;     init Q free list
;
allocate_node:
	mov  eax, [ node_fl ]                                   ; get node from free-list
	mov  ebx, [ eax ]                                       ; see if there is next node in the list
	test ebx, ebx
	jz   short .oops_no_more_nodes                          ; no nodes left, need to allocate an extra page

	cmpxchg [ node_fl ], ebx                                ; unlink the node from free-list
	jne short allocate_node                                 ; if free-list changed in mean time, we don't know what's going on so start again

	ret                                                     ; return the node in eax

.oops_no_more_nodes:
	mov ebx, NODEPAGE_size                                  ; allocate node page
	mov ebp, eax                                            ; an extra node that might be consumed by the allocator
	call allocate_memory
	test esi, esi
	jz .bah_we_re_outta_memory

	jmp short allocate_node


;========================================================================================
; create instance of comp of type t
method_create:
	METHOD_RET


;========================================================================================
; create instance of comp of type t at linear base b
method_create_at:
	METHOD_RET


;========================================================================================
; destroy instance of comp
method_destroy:
	METHOD_RET


;========================================================================================
; install new type from linear base
method_install:
	; Code scanner will be invoked here!

	METHOD_RET


;========================================================================================
; uninstall type
method_uninstall:
	METHOD_RET


;========================================================================================
; get comp's instance base
method_get_addr:
	METHOD_RET


;========================================================================================
; satisfy ORB memory request
method_linear:
	METHOD_RET


;========================================================================================
; get memory usage stats
;
; output:
;  EAX = information data comp ref
;
method_get_statistics:
	mov  eax, [ stats_ref ]
	test eax, eax
	jnz  short .already_allocated_ref

	METHOD_CREATE

.already_allocated_ref:
	METHOD_RET


section .data
node_fl:     dd nodepage + NODEPAGE.data                   ; nodes free list

ubase:       dd 0                                          ; bintree of allocated addresses
;usize:       dd 0                                          ; tertree of allocated sizes
fbase:       dd 0                                          ; bintree of free addresses
fsize:       dd 0                                          ; tertree of free sizes

; Statistics area (MEMSTATS)
stats_ref:   dd 0
stats:
.size:  dd MEMSTATS_size
.total: dd 0x12345678
.used:  dd 0
.free:  dd 0x87654321

stringz created_mimir, {"[MIMIR] Created memory manager",EOL}


section .bss

ALIGN 4
nodepage:    resb NODEPAGE_size                            ; first page of tree nodes

all_memory:  times 256 resb 0x07ffffff-(NODEPAGE_size/256) ; this covers all linear memory

