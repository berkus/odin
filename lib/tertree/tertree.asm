;========================================================================================
;
; Ternary Tree manipulation
;
; Copyright (c) 2001, Stanislav Karchebny <berk@madfire.net>
; Distributed under BSD License.
;
; Used binary tree algorithms from TAOCP3 by Don Knuth
; and adjusted them for ternary tree case.
;
; %define __TIMING for tree insert and remove timing
;
; TODO:
; ? thread-safe tree operations
;
;========================================================================================

GLOBAL tertree__insert_node
GLOBAL tertree__remove_node
GLOBAL tertree__find_node
GLOBAL tertree__find_ae_node


%define  ___COMPILE_TERTREE
%include "config"
%include "tertree.inc"
%include "timing.inc"


%ifdef __TIMING
GLOBAL tertree_insert_timing
GLOBAL tertree_remove_timing
GLOBAL tertree_inserts_done
GLOBAL tertree_removes_done
section .data
ALIGN 4
tertree_insert_timing: dd 0
tertree_inserts_done:  dd 0
tertree_remove_timing: dd 0
tertree_removes_done:  dd 0
section .bss
timing_temp:           resd 1
%endif


section .text
bits 32

;----------------------------------------------------------------------------------------
; Look for node whose key is given in EBX in the tree whose
; root pointer address is given in EDI.
;
; input: --
;  EBX = key
;  EDI = pointer to root node pointer (e.g. node **edi = &root_ptr)
;
; output: --
;  CF = 0  node found
;  ESI = pointer to node pointer (in parent node)
;  EDI = node
;
;  CF = 1  node not found
;  ESI trashed
;  EDI = node candidate to insert new node at
;
;  other registers unmodified
;
; -------------------------------------------------------------------
;
;  Algorithm S: Search for node in ternary tree
;               Algorithm is the same as for binary tree.
;  Input: K key of node to search
;         ROOT pointer to root node pointer
;  S1. P <- ROOT^, Q <- ROOT
;  S2. if K < P.key, goto S3
;      if K > P.key, goto S4
;      if K = P.key, goto S5
;  S3. if P.less = /\, goto S6
;   a  Q <- ^P.less
;   b  P <- P.less
;      goto S2
;  S4. if P.greater = /\, goto S6
;   a  Q <- ^P.greater
;   b  P <- P.greater
;      goto S2
;  S5. Node found, success.
;      Output:
;         P found node
;         Q pointer to node pointer
;  S6. Node not found, failed.
;
;  Registers used: EBX = K
;                  EDI = P
;                  ESI = Q
;
;----------------------------------------------------------------------------------------
tertree__find_node:
   cmp [ edi ], dword 0                                    ; test if the tree is not null
   je  short .failed                                       ; null, nowhere to look in

   mov esi, edi                                            ; S1   Q <- ROOT
   mov edi, [ edi ]                                        ; S1   P <- ROOT^ get tree root

.search:
   cmp ebx, [ edi + TERTREE_NODE.key ]                     ; S2   compare the keys
   jl  short .less
   jg  short .greater

.found:                                                    ; S5   equal keys
   clc                                                     ; returned node is the root of
   ret                                                     ; equal keys dlist

.failed:
	stc
	ret

.less:                                                     ; S3   new key is less, look up 'less' subtree
   cmp [ edi + TERTREE_NODE.less ], dword 0                ; is there a 'less' subtree exists?
   je  short .failed                                       ; nope, not found then
   lea esi, [ edi + TERTREE_NODE.less ]                    ; S3a  Q <- ^P.less
   mov edi, [ edi + TERTREE_NODE.less ]                    ; S3b  lets get on with 'less' subtree
   jmp short .search

.greater:                                                  ; S4   new key is greater, look up 'greater' subtree
   cmp [ edi + TERTREE_NODE.greater ], dword 0             ; is there a 'greater' subtree exists?
   je  short .failed                                       ; nope, not found then
   lea esi, [ edi + TERTREE_NODE.greater ]                 ; S4a  Q <- ^P.greater
   mov edi, [ edi + TERTREE_NODE.greater ]                 ; S4b  lets get on with 'greater' subtree
   jmp short .search


;----------------------------------------------------------------------------------------
; Look for node whose key is equal to or greater than given in EBX
; in the tree whose root pointer address is given in EDI.
;
; input: --
;  EBX = key
;  EDI = pointer to root node pointer (e.g. node **edi = &root_ptr)
;
; output: --
;  CF = 0  node found
;  ESI = pointer to node pointer (in parent node)
;  EDI = node
;
;  CF = 1  node not found
;  ESI trashed
;  EDI = node candidate to insert new node at
;
;  other registers unmodified
;
; -------------------------------------------------------------------
;
;  Algorithm S1: Search for equal or above node in ternary tree.
;  Input: K key of node to search
;         ROOT pointer to root node pointer
;  S1. P <- ROOT^, Q <- ROOT
;  S2. if K < P.key, goto S3
;      if K > P.key, goto S4
;      if K = P.key, goto S5
;  S3. if P.less = /\, goto S6    (found above node, don't fail)
;   a  Q <- ^P.less
;   b  P <- P.less
;      goto S2
;  S4. if P.greater = /\, goto S6
;   a  Q <- ^P.greater
;   b  P <- P.greater
;      goto S2
;  S5. Node found, success.
;      Output:
;         P found node
;         Q pointer to node pointer
;  S6. Node not found, failed.
;
;  Registers used: /EBX = K
;                  /EDI = P
;                  /ESI = Q
;
;----------------------------------------------------------------------------------------
tertree__find_ae_node:
	ret


;----------------------------------------------------------------------------------------
; Insert node in ESI in the tree whose root pointer address is given in EDI.
;
; input: --
;  ESI = new node
;  EDI = pointer to root node pointer (e.g. node **edi = &root_ptr)
;
; output: --
;  EBX, ESI trashed
;
;  CF = 0  node inserted
;  EAX = new node
;  EDI = parent node
;
;  CF = 1  node not inserted
;  EAX = new node
;  EDI = node with existing key (could be overwritten by new node data if necessary)
;
; NOTE: we use EDI for target node for the sake of copying
;       new node to old node if necessary.
;
;  other registers unmodified
;
; -------------------------------------------------------------------
;
;  Algorithm I: Insert node into ternary tree
;  Input: P node to insert
;         ROOT pointer to root node pointer
;  I1. if ROOT^ = /\, goto I6
;  I2. Q := tertree__find_node(P.key, ROOT)
;   a  if P.key = Q.key, goto I8.
;  I3. if P.key < Q.key, goto I5, otherwise goto I4.
;  I4. Q.greater := P, goto I7.
;  I5. Q.less := P, goto I7.
;  I6. ROOT := ^P, Q := /\, goto I7
;  I7. P.less := /\
;      P.greater := /\
;      Inserted node, success.
;      Output:
;         P inserted node
;         Q parent node
;  I8. P.equal := Q.equal
;      Q.equal := P
;      goto I7
;
;  Registers used: EAX = P
;                  EDI = Q
;                  EBX = P.key
;
;----------------------------------------------------------------------------------------
tertree__insert_node:
	start_timing timing_temp

   mov  eax, esi                                           ; save new node
   cmp  [ edi ], dword 0                                   ; I1   test if the tree is not null
   je   short .trivial                                     ; null, trivial case then

   mov  ebx, [ eax + TERTREE_NODE.key ]                    ; get new node key
   call tertree__find_node                                 ; I2   try to find that node
   jc   short .link_other                                  ; I2a  if node doesn't exist - insert at left or right

   mov ebx, [ edi + TERTREE_NODE.equal ]                   ; I8
   mov [ eax + TERTREE_NODE.equal ], ebx                   ; I8   P.equal := Q.equal
   mov [ edi + TERTREE_NODE.equal ], eax                   ; I8   Q.equal := P
   jmp short .link_ok

.link_other:
   cmp ebx, [ edi + TERTREE_NODE.key ]                     ; I3   is new node key greater?
   jl  short .link_left                                    ; no, link new node at left

.link_right:                                               ; yes, link new node at right
   mov [ edi + TERTREE_NODE.greater ], eax                 ; I4   point 'greater' to new node
   jmp short .link_ok

.link_left:
   mov [ edi + TERTREE_NODE.less    ], eax                 ; I5   point 'less' to new node
   jmp short .link_ok

.trivial:
   mov [ edi ], eax                                        ; I6   make this node new root
   xor edi, edi                                            ; it has no parent node

.link_ok:
   xor ebx, ebx
   mov [ eax + TERTREE_NODE.less    ], ebx                 ; "ground" new node
   mov [ eax + TERTREE_NODE.greater ], ebx                 ; "ground" new node

   stop_timing timing_temp, tertree_insert_timing, tertree_inserts_done
   clc
   ret

.failed:
   stop_timing timing_temp, tertree_insert_timing, tertree_inserts_done
   stc
   ret


;----------------------------------------------------------------------------------------
; Delete node with key in EBX from the tree whose root is given in EDI
;
; input: --
;  EBX = key of node to delete
;  EDI = pointer to root node pointer (e.g. node **edi = &root_ptr)
;
; output: --
;  CF = 0  node deleted
;  ESI = unlinked node (can be freed or whatever)
;  EDI = new root node
;  EAX,EBX trashed
;
;  CF = 1  node not deleted (key not present)
;  ESI, EDI trashed
;
;  other registers unmodified
;
; -------------------------------------------------------------------
;
;  Algorithm D: Delete from ternary tree
;  Input: K key of node to remove
;         ROOT pointer to root node pointer
;  D1. P := tertree__find_node(K, ROOT)
;   a  if P = /\, goto D6
;  D2. T <- P
;   a  if T.equal != /\, goto D7
;   b  if T.greater = /\, P := T.less, goto D5
;   c  if T.less    = /\, P := T.greater, goto D5
;  D3. R <- T.greater
;   a  if R.less = /\, R.less := T.less, P <- R, goto D5
;  D4. S <- R.less
;   a  while S.less != /\, R <- S, S <- R.less.
;   b  S.less := T.less       ( <=> S.less := P.less, since T = P from D2 )
;   c  R.less := S.greater
;   d  S.greater := T.greater ( <=> S.greater := P.greater, since T = P from D2 )
;   e' T <- P                 ( since we destroyed T in D4b-D4d )
;   e  P <- S
;      goto D5
;  D5. ROOT <- ^P
;      Node unlinked, success.
;      Output:
;         P new root node
;         T removed node
;  D6. Node not found, failed.
;  D7. T.equal.less := T.less
;      T.equal.greater := T.greater
;      P <- T.equal
;      goto D5
;
;  Registers used: EAX = ROOT
;                  EDI = P
;                  ESI = T
;                  EDX = R
;                  EBX = S
;
;----------------------------------------------------------------------------------------
tertree__remove_node:
	start_timing timing_temp

   call tertree__find_node                                 ; D1   find node
   jc   short .failed                                      ; D1a  not found - nothing to unlink

   push edx                                                ; preserve work register

   mov eax, esi                                            ; save pointer to node pointer
   mov esi, edi                                            ; D2   T <- P, this will be unlinked node

   cmp [ edi + TERTREE_NODE.equal ], dword 0               ; D2a  is 'equal' link nil?
   jne short .unlink_equal                                 ; no, so just unlink one of the equal nodes

   cmp [ edi + TERTREE_NODE.greater ], dword 0             ; D2b  is 'greater' link nil?
   jne short .try_less                                     ; no, try another link

   mov edi, [ edi + TERTREE_NODE.less ]                    ; D2b  'greater' link empty, 'less' link will be new root
   jmp short .done

.failed:                                                   ; (save us a short jump)
   stop_timing timing_temp, tertree_remove_timing, tertree_removes_done
   stc
   ret

.unlink_equal:                                             ; D7
	mov edx, [ edi + TERTREE_NODE.equal ]
	mov ebx, [ edi + TERTREE_NODE.less ]
	mov [ edx + TERTREE_NODE.less ], ebx                    ; D7   T.equal.less := T.less
	mov ebx, [ edi + TERTREE_NODE.greater ]
	mov [ edx + TERTREE_NODE.greater ], ebx                 ; D7   T.equal.greater := T.greater
	mov edi, ebx                                            ; D7   P <- T.equal
	jmp short .done

.try_less:
   cmp [ edi + TERTREE_NODE.less ], dword 0                ; D2c  is 'less' link nil?
   jne short .try_greater                                  ; no, follow the 'greater' subtree

   mov edi, [ edi + TERTREE_NODE.greater ]                 ; D2c  'less' link empty, 'greater' link will be new root
   jmp short .done

.try_greater:                                              ; find least in right subtree and unlink
   mov edx, [ edi + TERTREE_NODE.greater ]                 ; D3   R <- P.greater

   cmp [ edx + TERTREE_NODE.less ], dword 0                ; D3a  R.less = /\ ?
   jne short .follow_less

   mov ebx, [ esi + TERTREE_NODE.less ]                    ; D3a
   mov [ edx + TERTREE_NODE.less ], ebx                    ; D3a  R.less := P.less
   mov edi, edx                                            ; D3a  P <- R
   jmp short .done                                         ; D3a  goto D5

.follow_less:
   mov ebx, [ edx + TERTREE_NODE.less ]                    ; D4   S <- R.less

   cmp [ ebx + TERTREE_NODE.less ], dword 0                ; D4a  while S.less != /\
   je  short .found_least

   mov edx, ebx                                            ; D4a  R <- S
   jmp short .follow_less

.found_least:
   mov  esi, [ edi + TERTREE_NODE.less ]                   ; D4b
   mov  [ ebx + TERTREE_NODE.less ], esi                   ; D4b  S.less := P.less
   mov  esi, [ ebx + TERTREE_NODE.greater ]                ; D4c
   mov  [ edx + TERTREE_NODE.less ], esi                   ; D4c  R.less := S.greater
   mov  esi, [ edi + TERTREE_NODE.greater ]                ; D4d
   mov  [ ebx + TERTREE_NODE.greater ], esi                ; D4d  S.greater := P.greater
   mov  esi, edi                                           ; D4e' T <- P
   mov  edi, ebx                                           ; D4e  P <- S

.done:
   mov [ eax ], edi                                        ; D5   write root pointer
   pop  edx                                                ; restore work register

   stop_timing timing_temp, tertree_remove_timing, tertree_removes_done
   clc
   ret


