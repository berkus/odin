
struc TERTREE_NODE
   .key:       resd 1                                      ;\
   .less:      resd 1                                      ; > mirrors BTREE_NODE structure
   .greater:                                               ;/
   .up:        resd 1                                      ; for equal subtree, up node link
   .equal:     resd 1                                      ; equal subtree down node link
   .data:
endstruc


%ifndef ___COMPILE_TERTREE
EXTERN tertree__insert_node
EXTERN tertree__remove_node
EXTERN tertree__find_node
EXTERN tertree__find_ae_node
%endif