;========================================================================================
;
; Binary Tree manipulation
;
; Copyright (c) 2001, Stanislav Karchebny <berk@madfire.net>
; Distributed under BSD License.
;
; Used algorithms from TAOCP3 by Don Knuth.
;
; TODO:
; ? thread-safe tree operations
;
;========================================================================================

;----------------------------------------------------------------------------------------
; Look for node whose key is given in EBX in the tree whose
; root pointer address is given in EDI.
;
; input: --
;  EBX = key                                                        %1
;  EDI = pointer to root node pointer (e.g. node **edi = &root_ptr) %2
;
; output: --
;  CF = 0  node found
;  ESI = pointer to node pointer (in parent node)                   %3
;  EDI = node
;
;  CF = 1  node not found
;  ESI trashed
;  EDI = node candidate to insert new node at
;
;  other registers unmodified
;
; Macro instantiation:
; mbintree__find_node key_reg, root_ptr_reg, return_val_reg,
;                     key_offset, less_offset, greater_offset
;
; -------------------------------------------------------------------
;
;  Algorithm S: Search for node in binary tree
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
;  Registers used: EBX = K                                          %1
;                  EDI = P                                          %2
;                  ESI = Q                                          %3
;
;                  offset of the key field in the node              %4
;                  offset of the less pointer field                 %5
;                  offset of the greater pointer field              %6
;
;----------------------------------------------------------------------------------------
%macro mbintree__find_node 6.nolist
   cmp [ %2 ], dword 0                                     ; test if the tree is not null
   je  short .failed                                       ; null, nowhere to look in

   mov %3, %2                                              ; S1   Q <- ROOT
   mov %2, [ %2 ]                                          ; S1   P <- ROOT^ get tree root

.search:
   cmp %1, [ %2 + %4 ]                                     ; S2   compare the keys
   jl  short .less
   jg  short .greater

.found:                                                    ; S5   equal keys
   clc
   ret

.failed:
	stc
	ret

.less:                                                     ; S3   new key is less, look up 'less' subtree
   cmp [ %2 + %5 ], dword 0                                ; is there a 'less' subtree exists?
   je  short .failed                                       ; nope, not found then
   lea %1, [ %2 + %5 ]                                     ; S3a  Q <- ^P.less
   mov %2, [ %2 + %5 ]                                     ; S3b  lets get on with 'less' subtree
   jmp short .search

.greater:                                                  ; S4   new key is greater, look up 'greater' subtree
   cmp [ %2 + %6 ], dword 0                                ; is there a 'greater' subtree exists?
   je  short .failed                                       ; nope, not found then
   lea %1, [ %2 + %6 ]                                     ; S4a  Q <- ^P.greater
   mov %2, [ %2 + %6 ]                                     ; S4b  lets get on with 'greater' subtree
   jmp short .search
%endmacro


;----------------------------------------------------------------------------------------
; Insert node in ESI in the tree whose root pointer address is given in EDI.
;
; NOTE: we use EDI for target node for the sake of copying
;       new node to old node if necessary.
;
; input: --
;  ESI = new node                                                   %1
;  EDI = pointer to root node pointer (e.g. node **edi = &root_ptr) %2
;
; output: --
;  EBX, ESI trashed                                                 %5, %1
;
;  CF = 0  node inserted
;  EAX = new node                                                   %3
;  EDI = parent node                                                %4
;
;  CF = 1  node not inserted
;  EAX = new node                                                   %3
;  EDI = node with existing key (could be overwritten by new node data if necessary) %4
;
;  other registers unmodified
;
; Macro instantiation:
; mbintree__insert_node node_reg, root_ptr_reg, return_val_reg,
;                     key_offset, less_offset, greater_offset
;
; -------------------------------------------------------------------
;
;  Algorithm I: Insert node into binary tree
;  Input: P node to insert
;         ROOT pointer to root node pointer
;  I1. if ROOT^ = /\, goto I6
;  I2. Q := btree__find_node(P.key, ROOT)
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
;  I8. Failed, node already exists.
;      Output:
;         P node failed to insert
;         Q existing node
;
;  Registers used: EAX = P                                          %3
;                  EDI = Q                                          %4
;                  EBX = P.key                                      %5
;
;                  offset of the key field in the node              %6
;                  offset of the less pointer field                 %7
;                  offset of the greater pointer field              %8
;
;----------------------------------------------------------------------------------------
%macro mbintree__insert_node 8.nolist
   mov  %3, %1                                             ; save new node
   cmp  [ %2 ], dword 0                                    ; I1   test if the tree is not null
   je   short .trivial                                     ; null, trivial case then

   mov  %5, [ %3 + %6 ]                                    ; get new node key
   call bintree__find_node                                 ; I2   try to find that node
   jnc  short .failed                                      ; I2a  node exists - don't insert

   cmp %5, [ %4 + %6 ]                                     ; I3   is new node key greater?
   jl  short .link_left                                    ; no, link new node at left

.link_right:                                               ; yes, link new node at right
   mov [ %4 + %8 ], %3                                     ; I4   point 'greater' to new node
   jmp short .link_ok

.link_left:
   mov [ %4 + %7 ], %3                                     ; I5   point 'less' to new node
   jmp short .link_ok

.trivial:
   mov [ %4 ], %3                                          ; I6   make this node new root
   xor %4, %4                                              ; it has no parent node

.link_ok:
   xor %5, %5
   mov [ %3 + %7 ], %5                                     ; "ground" new node
   mov [ %3 + %8 ], %5                                     ; "ground" new node
   clc
   ret

.failed:
   stc
   ret
%endmacro


;----------------------------------------------------------------------------------------
; Delete node with key in EBX from the tree whose root is given in EDI
;
; input: --
;  EBX = key of node to delete                                      %1
;  EDI = pointer to root node pointer (e.g. node **edi = &root_ptr) %2
;
; output: --
;  CF = 0  node deleted
;  ESI = unlinked node (can be freed or whatever)                   %3
;  EDI = new root node                                              %2
;  EAX,EBX,EDX trashed                                              %4, %1, %5
;
;  CF = 1  node not deleted (key not present)
;  ESI, EDI trashed                                                 %3, %2
;
;  other registers unmodified
;
; -------------------------------------------------------------------
;
;  Algorithm D: Delete from binary tree
;  Input: K key of node to remove
;         ROOT pointer to root node pointer
;  D1. P := btree__find_node(K, ROOT)
;   a  if P = /\, goto D6
;  D2. T <- P
;   a  if T.greater = /\, P := T.less, goto D5
;   b  if T.less    = /\, P := T.greater, goto D5
;  D3. R <- T.greater
;   a  if R.less = /\, R.less := T.less, P <- R, goto D5
;  D4. S <- R.less
;   a  while S.less != /\, R <- S, S <- R.less.
;   b  S.less := T.less       ( <=> S.less := P.less, since T = P from D2 )
;   c  R.less := S.greater
;   d  S.greater := T.greater ( <=> S.greater := P.greater, since T = P from D2 )
;   e' T <- P                 ( since we destroyed T in D4b-D4d )
;   e  P <- S
;  D5. ROOT <- ^P
;      Node unlinked, success.
;      Output:
;         P new root node
;         T removed node
;  D6. Node not found, failed.
;
;  Registers used: EAX = ROOT                                       %4
;                  EDI = P                                          %2
;                  ESI = T                                          %3
;                  EDX = R                                          %5
;                  EBX = S                                          %1
;
;                  offset of the key field in the node              %6
;                  offset of the less pointer field                 %7
;                  offset of the greater pointer field              %8
;                  name of tree search function                     %9
;
;----------------------------------------------------------------------------------------
%macro mbintree__remove_node 9.nolist
   call %9                                                 ; D1   find node
   jc   short .failed                                      ; D1a  not found - nothing to unlink

   mov %4, %3                                              ; save pointer to node pointer
   mov %3, %2                                              ; D2   T <- P, this will be unlinked node

   cmp [ %2 + %8 ], dword 0                                ; D2a  is 'greater' link nil?
   jne short .try_less                                     ; no, try another link

   mov %2, [ %2 + %7 ]                                     ; D2a  'greater' link empty, 'less' link will be new root
   jmp short .done

.try_less:
   cmp [ %2 + %7 ], dword 0                                ; D2b  is 'less' link nil?
   jne short .try_greater                                  ; no, follow the 'greater' subtree

   mov %2, [ %2 + %8 ]                                     ; D2b  'less' link empty, 'greater' link will be new root
   jmp short .done

.try_greater:                                              ; find least in right subtree and unlink
   mov %5, [ %2 + %8 ]                                     ; D3   R <- P.greater

   cmp [ %5 + %7 ], dword 0                                ; D3a  R.less = /\ ?
   jne short .follow_less

   mov %1, [ %3 + %7 ]                                     ; D3a
   mov [ %5 + %7 ], %1                                     ; D3a  R.less := P.less
   mov %2, %5                                              ; D3a  P <- R
   jmp short .done                                         ; D3a  goto D5

.follow_less:
   mov %1, [ %5 + %7 ]                                     ; D4   S <- R.less

   cmp [ %1 + %7 ], dword 0                                ; D4a  while S.less != /\
   je  short .found_least

   mov %5, %1                                              ; D4a  R <- S
   jmp short .follow_less

.found_least:
   mov  %3, [ %2 + %7 ]                                    ; D4b
   mov  [ %1 + %7 ], %3                                    ; D4b  S.less := P.less
   mov  %3, [ %1 + %8 ]                                    ; D4c
   mov  [ %5 + %7 ], %3                                    ; D4c  R.less := S.greater
   mov  %3, [ %2 + %8 ]                                    ; D4d
   mov  [ %1 + %8 ], %3                                    ; D4d  S.greater := P.greater
   mov  %3, %2                                             ; D4e' T <- P
   mov  %2, %1                                             ; D4e  P <- S

.done:
   mov [ %4 ], %2                                          ; D5   write root pointer
   clc
   ret

.failed:
   stc
   ret
%endmacro

