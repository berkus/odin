
struc BINTREE_NODE
	.key:			resd 1                                      ; node key
	.less:		resd 1                                      ; less key subtree
	.greater:	resd 1                                      ; greater key subtree
	.data:
endstruc

%ifndef ___COMPILE_BINTREE
EXTERN bintree__insert_node
EXTERN bintree__remove_node
EXTERN bintree__find_node
%endif