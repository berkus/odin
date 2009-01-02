; P <- ROOT^
;
;
;



  mov parentnodeptr, [rootptr]
  mov returnoffset, -1
  cmp parentnodeptr, returnoffset
  jz short %%not_found
%%browsing:
  cmp key, [parentnodeptr + NODE.key]
  ja short %%test_left_node_presence
  jb short %%test_right_node_presence
  mov returnoffset, NODE.center
  cmp [parentnodeptr + NODE.center], byte -1
  clc
  retn
%%left_would_be_link_point:
  cmp returnoffset, byte -1
  jnz short %%safe_node_recover
  mov returnoffset, NODE.left
%%not_found:
  stc
  retn
%%test_left_node_presence:
  cmp [parentnodeptr + NODE.left], byte -1
  jz short %%left_would_be_link_point
  mov parentnodeptr, [parentnodeptr + NODE.left]
  jmp short %%browsing
%%test_right_node_presence:
  cmp [parentnodeptr + NODE.right], byte -1
  jz short %%right_would_be_link_point
  mov returnoffset, parentnodeptr
  mov parentnodeptr, [parentnodeptr + NODE.right]
  jmp short %%browsing
%%safe_node_recover:
  mov parentnodeptr, returnoffset
%%right_would_be_link_point:
  mov returnoffset, NODE.right
  clc
  retn
