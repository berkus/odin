;========================================================================================
;
; Testsuite for bintree binary tree manipulation functions
;
; This input sequence builds linear tree:
;aquarius aries cancer capricorn gemini leo libra pisces sagittarius scorpio taurus virgo
;
; This input sequence builds zigzag tree:
;aquarius virgo aries taurus cancer scorpio capricorn sagittarius gemini pisces leo libra
;
; This input sequence builds more balanced tree:
;capricorn aquarius pisces aries taurus gemini cancer leo virgo libra scorpio sagittarius
;
; TODO:
; - make about 100,000 insertions/removals for more accurate timing test.
;
;========================================================================================

GLOBAL test_bintree

%include "config"
%include "bintree.inc"
%include "console.inc"
%include "debug.inc"

%macro btree_insert 2
   mov edi, %1
   mov esi, %2
   call bintree__insert_node
%endmacro

%macro btree_remove 2
   mov edi, %1
   mov ebx, %2
   call bintree__remove_node
%endmacro

section .text
bits 32

test_bintree:

   ;=====================================================================================
   ; -- create and print linear tree
   ;=====================================================================================

   mov [ root ], dword 0                                   ; empty tree

   btree_insert root, aquarius
   btree_insert root, aries
   btree_insert root, cancer
   btree_insert root, capricorn
   btree_insert root, gemini
   btree_insert root, leo
   btree_insert root, libra
   btree_insert root, pisces
   btree_insert root, sagittarius
   btree_insert root, scorpio
   btree_insert root, taurus
   btree_insert root, virgo

   mov esi, tree_linear
   call console__print
   mov edi, root
   call btree__print_tree
   call console__wait_ack

   ; -- remove half the nodes and print tree again

   mov ecx, 12

.kill_node:
   btree_remove root, ecx                                  ; remove 12 10 8 6 4 2
   jnc short .go_kill
   call removal_failed
.go_kill:
   dec ecx                                                 ; kill each 2nd node
   loop .kill_node

   mov esi, tree_linear_pruned
   call console__print
   mov edi, root
   call btree__print_tree
   call console__wait_ack

   ; -- remove another half the nodes and start over again

   mov ecx, 12

.kill_node2:
   dec ecx                                                 ; kill each 2nd node
   btree_remove root, ecx                                  ; remove 11 9 7 5 3 1
   jnc short .go_kill2
   call removal_failed
.go_kill2:
   loop .kill_node2

   ;=====================================================================================
   ; -- create and print zigzag tree
   ;=====================================================================================

   mov [ root ], dword 0                                   ; start over again

   btree_insert root, aquarius
   btree_insert root, virgo
   btree_insert root, aries
   btree_insert root, taurus
   btree_insert root, cancer
   btree_insert root, scorpio
   btree_insert root, capricorn
   btree_insert root, sagittarius
   btree_insert root, gemini
   btree_insert root, pisces
   btree_insert root, leo
   btree_insert root, libra

   mov esi, tree_zigzag
   call console__print
   mov edi, root
   call btree__print_tree
   call console__wait_ack

   ; -- remove half the nodes and print tree again

   mov ecx, 12

.kill_node3:
   btree_remove root, ecx                                  ; remove 12 10 8 6 4 2
   jnc short .go_kill3
   call removal_failed
.go_kill3:
   dec ecx                                                 ; kill each 2nd node
   loop .kill_node3

   mov esi, tree_zigzag_pruned
   call console__print
   mov edi, root
   call btree__print_tree
   call console__wait_ack

   ; -- remove another half the nodes and start over again

   mov ecx, 12

.kill_node4:
   dec ecx                                                 ; kill each 2nd node
   btree_remove root, ecx                                  ; remove 11 9 7 5 3 1
   jnc short .go_kill4
   call removal_failed
.go_kill4:
   loop .kill_node4

   ;=====================================================================================
   ; -- create and print balanced tree
   ;=====================================================================================

   mov [ root ], dword 0                                   ; start over again

   btree_insert root, capricorn
   btree_insert root, aquarius
   btree_insert root, pisces
   btree_insert root, aries
   btree_insert root, taurus
   btree_insert root, gemini
   btree_insert root, cancer
   btree_insert root, leo
   btree_insert root, virgo
   btree_insert root, libra
   btree_insert root, scorpio
   btree_insert root, sagittarius

   mov esi, tree_balanced
   call console__print
   mov edi, root
   call btree__print_tree
   call console__wait_ack

   ; -- remove half the nodes and print tree again

   mov ecx, 12

.kill_node5:
   btree_remove root, ecx                                  ; remove 12 10 8 6 4 2
   jnc short .go_kill5
   call removal_failed
.go_kill5:
   dec ecx                                                 ; kill each 2nd node
   loop .kill_node5

   mov esi, tree_balanced_pruned
   call console__print
   mov edi, root
   call btree__print_tree
   call console__wait_ack

   ; -- remove another half the nodes and finish with it

   mov ecx, 12

.kill_node6:
   dec ecx                                                 ; kill each 2nd node
   btree_remove root, ecx                                  ; remove 11 9 7 5 3 1
   jnc short .go_kill6
   call removal_failed
.go_kill6:
   loop .kill_node6

   ; -- should end up with empty tree

   mov esi, tree_balanced_empty
   call console__print
   mov edi, root
   call btree__print_tree

%ifdef __TIMING
	EXTERN bintree_insert_timing
	EXTERN bintree_remove_timing
	EXTERN bintree_inserts_done
	EXTERN bintree_removes_done

   ; -- print timings

   mov eax, [ bintree_insert_timing ]
   xor edx, edx
   div dword [ bintree_inserts_done ]
   mov ebx, edx                                            ; store remainder

   mov esi, done_time
   call console__print
   mov edx, [ bintree_inserts_done ]
   call console__print_dword
   mov esi, insert_time
   call console__print
   mov edx, eax
   call console__print_dword
   mov al, '.'
   call console__print_char
   mov edx, ebx
   call console__print_dword
   call console__newline

   mov eax, [ bintree_remove_timing ]
   xor edx, edx
   div dword [ bintree_removes_done ]
   mov ebx, edx                                            ; store remainder

   mov esi, done_time
   call console__print
   mov edx, [ bintree_removes_done ]
   call console__print_dword
   mov esi, remove_time
   call console__print
   mov edx, eax
   call console__print_dword
   mov al, '.'
   call console__print_char
   mov edx, ebx
   call console__print_dword
   call console__newline

%endif

   ret


removal_failed:
   mov esi, removal_fail
   call console__print
   mov edx, ebx
   call console__print_dword
   call console__newline
   call console__wait_ack
   ret


; EDI = pointer to node pointer of tree to print
; use pre-order traversal (i.e. this node, left subtree, right subtree) recursively
btree__print_tree:
   cmp  [ edi ], dword 0
   je   short .return

   push edi
   mov  edi, [ edi ]

   inc dword [indent]

   mov  ecx, [ indent ]
.indent:
   mov  al, ' '
   call console__print_char
   loop .indent

;  call dump_node
   lea  esi, [ edi + BINTREE_NODE.data ]
   call console__print
   call console__newline

   lea edi, [ edi + BINTREE_NODE.less ]
   cmp  [ edi ], dword 0
   je   short .no_left
   mov al, 'L'                                             ; left subtree
   call console__print_char
   call btree__print_tree
.no_left:
   pop  edi
   push edi
   mov  edi, [ edi ]
   lea  edi, [ edi + BINTREE_NODE.greater ]
   cmp  [ edi ], dword 0
   je   short .no_right
   mov al, 'R'                                             ; right subtree
   call console__print_char
   call btree__print_tree
.no_right:

   dec dword [indent]

   pop  edi
.return:
   ret

%if 0
dump_node: ;in EDI to screen
   mov esi, node_id
   call console__print
   mov edx, [ edi + BINTREE_NODE.key ]
   call console__print_dword
   mov esi, node_at
   call console__print
   mov edx, edi
   call console__print_dword
   mov esi, node_less
   call console__print
   mov edx, [ edi + BINTREE_NODE.less ]
   call console__print_dword
   mov esi, node_greater
   call console__print
   mov edx, [ edi + BINTREE_NODE.greater ]
   call console__print_dword
   mov esi, node_data
   call console__print
   lea esi, [ edi + BINTREE_NODE.data ]
   call console__print
   call console__newline
   call console__wait_ack
   ret
%endif

section .data

%ifdef __TIMING
done_time:                   db "[BTREETEST] Done ",0
insert_time:                 db " inserts in avg time: ",0
remove_time:                 db " removes in avg time: ",0
%endif

tree_linear:                 db "[BTREETEST] Dumping linear tree",EOL,0
tree_linear_pruned:          db "[BTREETEST] Dumping pruned linear tree",EOL,0
tree_zigzag:                 db "[BTREETEST] Dumping zigzag tree",EOL,0
tree_zigzag_pruned:          db "[BTREETEST] Dumping pruned zigzag tree",EOL,0
tree_balanced:               db "[BTREETEST] Dumping balanced tree",EOL,0
tree_balanced_pruned:        db "[BTREETEST] Dumping pruned balanced tree",EOL,0
tree_balanced_empty:         db "[BTREETEST] Dumping empty balanced tree",EOL,0

removal_fail:                db "[BTREETEST] Node removal failed, node ",0

%if 0
node_id: db "Node ",0
node_at: db " @ ",0
node_less: db ", less ",0
node_greater: db ", greater ",0
node_data: db ", data ",0
%endif

ALIGN 4
indent: dd 0

root:      dd 0

aquarius:    istruc BINTREE_NODE
             at BINTREE_NODE.key, dd 1
             iend
             db "Aquarius",0

aries:       istruc BINTREE_NODE
             at BINTREE_NODE.key, dd 2
             iend
             db "Aries",0

cancer:      istruc BINTREE_NODE
             at BINTREE_NODE.key, dd 3
             iend
             db "Cancer",0

capricorn:   istruc BINTREE_NODE
             at BINTREE_NODE.key, dd 4
             iend
             db "Capricorn",0

gemini:      istruc BINTREE_NODE
             at BINTREE_NODE.key, dd 5
             iend
             db "Gemini",0

leo:         istruc BINTREE_NODE
             at BINTREE_NODE.key, dd 6
             iend
             db "Leo",0

libra:       istruc BINTREE_NODE
             at BINTREE_NODE.key, dd 7
             iend
             db "Libra",0

pisces:      istruc BINTREE_NODE
             at BINTREE_NODE.key, dd 8
             iend
             db "Pisces",0

sagittarius: istruc BINTREE_NODE
             at BINTREE_NODE.key, dd 9
             iend
             db "Sagittarius",0

scorpio:     istruc BINTREE_NODE
             at BINTREE_NODE.key, dd 10
             iend
             db "Scorpio",0

taurus:      istruc BINTREE_NODE
             at BINTREE_NODE.key, dd 11
             iend
             db "Taurus",0

virgo:       istruc BINTREE_NODE
             at BINTREE_NODE.key, dd 12
             iend
             db "Virgo",0
