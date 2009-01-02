
; -- Stacks

struc STACK_EL
   .next_esp:      resd 1 ; 0x00
   .next_ss:       resd 1 ; 0x04
   .prev_esp:      resd 1 ; 0x08
   .prev_ss:       resd 1 ; 0x0C
   .next_ref:      resd 1 ; 0x10
   .prev_ref:      resd 1 ; 0x14
   .call_depth:    resd 1 ; 0x18
   .tcall_els:     resd 1 ; 0x1C
   .this_ref:      resd 1 ; 0x20
   .limit:         resd 1 ; 0x24
   .prev_ptr:      resd 1 ; 0x28
   .next_ptr:      resd 1 ; 0x2C
   .resume_ctx:    resd 1 ; 0x30
   .nomem_xcp_ptr: resd 1 ; 0x34
   .old_esp:       resd 1 ; 0x38
   .nomem_xcp_ref: resd 1 ; 0x3C

   .END_OF_CHAIN   equ 0xFFFF

   .INIT_FL_SZ     equ 8096    ; This value is really a hack because Greg never managed to
                               ; handle linear exceptions normally. This is FIXME.
endstruc


struc TCALL_EL
   .next:          resd 1 ; 0x00
   .ret_offs:      resd 1 ; 0x04
   .ret_seg:       resd 1 ; 0x08
   .ret_ref:       resd 1 ; 0x0C

   .INIT_FL_SZ     equ 10
endstruc
