;========================================================================================
;
; Instance deletion
;
;========================================================================================

GLOBAL method_destroy

; for exception handling
GLOBAL method_destroy.dtor_cs_fault
GLOBAL method_destroy.dtor_ds_fault


%include "orb.inc"
%include "cdt.inc"
%include "orb_link.inc"
%include "stack.inc"
%include "type.inc"
%include "mt.inc"


section .text
bits 32

;======================================= DESTROY ========================================
; Need to free up EAX contiguous refereces, starting from EBX
;
method_destroy:

   ; -- save regs we need to preserve

   push     ds
   push     ebx
   push     ecx
   push     edx
   push     esi

   sub      esp, 4                        ;place for a local variable[12]
   mov      ecx, ORB.STATIC_SEL
   mov      ds, ecx

%ifdef _DEBUG
   mov      ecx, ebx
   add      ecx, eax
   dec      ecx
   cmp      dword ecx, [ max_ref ]
   jg       .throw_noref0
%endif

.destroy_loop:
   ;-------------------------------------------------------------------------
   ;ECX = ref_free_list_number to add refs to
   ;Find the appropriate ObjRef free-list to put stuff on

   bsr      ecx, eax                   ;get the biggest FL number -> ecx
   jnz      short .more                ;if the zero flag was set, this means EAX was zero (i.e. destroy /no/ references)

   ;------------------------------------------------------------------------
   ;if control reaches here, we're all done (i.e. no more refs to destroy)
   add      esp, 4                        ;clear space for local variable [12]
   pop      esi                        ;unstack saved regs
   pop      edx
   pop      ecx
   pop      ebx
   pop      ds
   retf                             ;return to caller

   ;------------------------------------------------------------------------
   ;ok, we're gonna destroy us some references

.more:
   ;ok, we have the FL number, but let's make sure it's not too big
   cmp      ecx, ORB.MAX_FL_NUMBER
   jl       short .fl_in_range
   mov      ecx, ORB.MAX_FL_NUMBER                  ;we don't have a free list with blocks of as many as EAX references -- need to chop it up.

.fl_in_range:
   ;--------------------------------------------------------------------------
   ; EDX = number_of_references_to_destroy_this_go
   ;ok, we're gonna destroy us some references
   ;now that we know which free-list we're appending to, let's get the number
   ;of references that free-list holds -> edx (i.e. 2^(ecx))
   mov      edx, 1                        ;the free-list we've chosen contains 2^(ecx) references
   shl      edx, cl                       ;edx contains the block size we're freeing this go (ecx will never be > 255 (in fact, never > 31))
   sub      eax, edx                      ;note how many we've let go

   ; -- ESI = first_objref_not_to_destroy
   ; right then, let's call the destructor for each before returning it to the free-list

   shl      ebx, 5
   mov   dword [ orb_cdt + ebx + CDT.mcount ], 0           ;we're going to clobber its CDT entry; don't let any threads in!
   mov   dword [ orb_cdt + ebx + CDT.mtbl ], 0             ;recall that the first reference of a zombified block contains the number of zombies in its MT field in CDT.
   mov   byte  [ esp ], 0                                  ;we keep a local variable [12] of whether any references were left as zombies.
   shr      ebx, 5                                         ;this block might not be zombified, but we assume it might be...

   ; -- Call the destructor for each ref in this reference-block

   mov      esi, ebx
   add      esi, edx                                       ;we're going to call each reference's destructor.  we put ebx + number_of_references_to_destroy

.next_dtor:
   push     ebx                        ;Save away EBX which contains the ObjRef [10]
   shl      ebx, 5
%ifdef _DEBUG
   cmp   dword [ orb_cdt + ebx + CDT.ds_sel ], 0xFFFFFFFF         ;Are we trying to destroy a non-existant component? (only check if in debug mode)
   je    .destroy_error
%endif

   ; -- As of this point we make the destroyee a zombie.
   ; However, need to preserve its selector if cached in GDT so we can free it

   inc   dword [ orb_cdt + ebx + CDT.gdt_lock ]              ;lock it in the GDT if cached (to avoid race between us and a reject from GDT).  Note: no need to unlock it as the selector will get freed whatever
   mov      edi, [ orb_cdt + ebx + CDT.ds_sel ]          ;Remember the reference's selector as we're about to clobber CDT entry with zombie selector [1]

   cmp   dword [ orb_cdt + ebx + CDT.type_ptr ], TYPE_PTR_DATA        ;First of all, we have to take special action with built-in types.
   je    .done_dtor                    ;  - if we're destroying a null component, there's no destructor to call
   push     eax                        ; preserve g/p regs for later [11]
   push     ecx                        ; note: if we're going to call destroy_stack or not, we still need to preserve these regs
   push     edx
   cmp   dword [ orb_cdt + ebx + CDT.type_ptr ], TYPE_PTR_STACK       ;
   je       .destroy_stack                   ;  - if it's a stack, no dtor, but we'd better unlink from stack chain and free stack element

   ; -- If we get here we have a conventional type, and so need to call the dtor.  However,
   ; first we need to make sure DS is cached in GDT because ref is now a zombie, so we
   ; can't rely on CDT's selector entry.

   shr      ebx, 5
   cmp      di, CDT.SEL_TYPE_UNCACHED              ;Is segment selector cached in GDT?
   jne      short .already_cached                     ;If so, no need to bring it in
   push     ebx                        ;pass ObjRef to reload (stored in EBX)

   call     load_gdt
   mov      edi, eax                   ;Store the selector in edi
   add      esp, 4

.already_cached:
   push     edi                        ;Need to preserve EDI for immenent call to dtor
   push     ebx
   push     esi                        ;Need to preserve ESI in immenent call to dtor
   push  dword [ current_comp ]                    ;Need to remember who called orb::create() [2]
   mov      eax, [ current_comp ]                  ;Pass the destroyer of the doomed component in eax
   mov      [ current_comp ], ebx                  ;We're gonna be calling the object we're to destroy
   shl      ebx, 5                        ;Change the ObjRef into an Index into the CDT

   ; (simulate CALL here)
   ; Need to set tcall_depth to zero, saving old tcall_depth away
   ; Also need to save the outgoing old_limit away too.

   push  dword ORB.TEXT                        ;push our CS and an EIP to make it look like the ...
   push  dword .dtor_return                     ;... FAR CALL that ORB::ret() will expect to have happened [3]
   mov      ecx, ss                       ;Get stack segment
   mov      dx, [ orb_gdt + ecx ]                 ;get the original SS limit ( in advance for pairing )    FIXME -- must work with stacks > 64K
   push  dword ORB.DYNAMIC_REF                     ;we're the caller, so push the ORB's reference
   mov      esi, [ active_stack ]
   push  dword [ esi + STACK_EL.limit ]             ;push the old limit
   push  dword [ esi + STACK_EL.tcall_els ]              ;push the old tcall-private-stack
                                 ;Note: above 2 pushes might be cheaper via regs (pairing), but none free :-(

   ; -- Incrememnt call depth and dec lock count appropriately

   inc   dword [ esi + STACK_EL.call_depth ]           ;increment the call-depth

   ; -- Now we need to shrink the stack.  The limit gets set to esp

   mov   [ esi + STACK_EL.limit ], edx           ;Set the old SS.limit
   mov   dword [ esi + STACK_EL.tcall_els ], 0           ;zero t-call private-stack
   mov   dx, sp                        ;
   dec   dx                      ;
   mov   [ orb_gdt + ecx ], dx                 ;modify ss.limit  (sp - 1) -> gdt[ ss ].limit[0..15])
   mov   ss, cx                        ;reload the stack segment.

   push  dword [ esi + STACK_EL.old_esp ]
   mov      [ esi + STACK_EL.old_esp ], esp

   ; -- Finally we load the caller's ObjRef into EAX (for server
   ; authentication), get the method table, load callee's DS and
   ; jump into the callee at method's offset.

   mov      esi, [ orb_cdt + ebx + CDT.type_ptr ]               ;load the method table pointer.  However, we clobbered mtbl with the number of zombies...
   mov      esi, [ esi + CDT.mtbl ]                             ;... in this reference-block, so we get the MT ptr from the type's CDT, not our CDT.
.dtor_ds_fault:
   mov      ds, edi                          ;load target DS (note DS got put in EDI at[1])
.dtor_cs_fault:
   jmp far     [ fs : esi + MT.dtor ]                  ;jump into according to mt.

.dtor_return:                                ;Because we pushed this label and ORB's CS at [3], the "retf" in ORB::ret() will return us to here.
   pop   dword [ current_comp ]                       ;restore our caller from the push at [2]
   pop      esi
   pop      ebx
   pop      edi
   shl      ebx, 5
   ;mov     edi, [ orb_cdt + ebx + CDT.ds_sel ]
   mov   word  [ orb_cdt + ebx + CDT.ds_sel ], CDT.SEL_TYPE_ZOMBIE      ;FIXME: In multiprocessor ORBs we probably want to preempt any threads currently executing in zombie(?)
.stack_destroy_return:                             ;we come back here if we destroyed a stack
   pop      edx                           ;restore the g/p regs saved at [11]
   pop      ecx
   pop      eax
.done_dtor:

.free_sel:
   and      edi, 0xFFFF
   cmp      edi, CDT.SEL_TYPE_UNCACHED                ;was the destroyee's selector cached in the GDT?
   je       short .not_cached                      ;if not, no need to free the selector
   push     eax
   mov      eax, [ sel_free ]                    ;find the base of the selector free-list
   mov      [ orb_gdt + edi ], eax                   ;point the element we're freeing at the selector free-list
   cmpxchg  [ sel_free ], edi                    ;and attempt to point free-list at freed element ATOMICALLY
   jne      .free_sel                        ;if we didn't manage to do it atomically, we'd better try again!
   pop      eax

.not_cached:
   cmp   dword [ orb_cdt + ebx + CDT.call_count ], 0             ;are there any threads pending on this zombie?
   jne      short .zombify                      ;if so, we don't free up the reference just yet

   mov   dword [ orb_cdt + ebx + CDT.ds_sel ], 0xFFFFFFFF;           ;mark the entry's selector fields as -1, thus invalidating the reference we've just destroyed
   jmp      short .not_zombie

.zombify:
   mov      byte  [ esp + 8 ], 1                      ;we're zombifying -- mark the local variable [12]
   mov      dword [ orb_cdt + ebx + CDT.zombie_ref ], esi               ;
   sub      dword [ orb_cdt + ebx + CDT.zombie_ref ], edx               ;A zombie's LOCK_COUNT is actually the first ref of this reference-block
   push     esi
   mov      esi, [ orb_cdt + ebx + CDT.zombie_ref ]               ;Get the first reference of this block into ESI
   shl      esi, 5
   mov      [ orb_cdt + esi + CDT.descr1 ], edx              ;The first reference of a zombified reference-block stores the length of the block in its desc1 field
   inc      word  [ orb_cdt + esi + CDT.zombie_count ]               ;the first reference of a zombified reference-block stores the number of zombies in the block in its mt field.
   pop      esi
.not_zombie:
   pop      ebx                           ;restore the ObjRef into EBX saved at [10]

   inc      ebx                           ;move EBX to the next reference we need to destruct [*]
   cmp      ebx, esi                      ;have we inc'd ebx to destroy 'the first objref we're not to destory'?
   jne      .next_dtor                    ;if so, we'd better not destroy it.  otherwise; go destroy it

   ; -- ok, all the destructors have been called; let's add the reference block to free list,
   ;but only if no references in this block were zombified.

   cmp   byte  [ esp ], 0                       ;did we zombify any references? (the local variable [12] should still be zero if no references were zombified)
   jne      .destroy_loop                       ;if ANY references in this reference block were zombified, we can't free the block yet.
   push     eax                           ;preserve eax
   mov      esi, ebx                      ;take a copy of the ref which we will point into the CDT
   sub      esi, edx                      ;we've incremented ebx at[*]; let's get it back to the original
.link_fl_el:
   shl      esi, 5
   mov      eax, [ cdt_fl  + ecx * 4 ]                  ;get the free-list base-> eax
   mov      [ orb_cdt + esi + CDT.next ], eax               ;link the free-list into this reference
   shr      esi, 5
   cmpxchg     [ cdt_fl + ecx * 4 ], esi                ;attempt to link this reference into the free list
   jnz      .link_fl_el                      ;if the free-list base changed, we'd better try again...
   pop      eax                           ;restore eax

   jmp      .destroy_loop

.destroy_stack:

   ;We destroying a stack component.  We need to a) unlink it from any stack-chain
   ;it might be in, and b) free the stack element.
   ;When removing from a stack-chain there are two things to do:
   ;1) Set previous's nexts to zero so we're removed from stack-chain
   ;2) Free memory used by stack element.
   ;NOTE: This is a privileged operation.  As such it isn't safe.  It's not thread-safe
   ;and if you try and remove a stack el of an active thread you've got problems
   ;There are exceptions thrown in debug builds
   ;                       EAX = pointer to our element
   ;                       ECX = pointer to previous stack element

   mov      eax, [ orb_cdt + ebx + CDT.stack ]               ;we need to know the address of our stack element

%ifdef _DEBUG

   ; -- Do some sanity tests in debug builds

   xor   edx, edx
   cmp   dword [ eax + STACK_EL.call_depth ], 0
   jne   .err_in_stack_destroy                  ;if we have any normal-call returns pending we can't be destroyed
   inc   edx
   cmp   dword [ eax + STACK_EL.tcall_els ], 0
   jne   .err_in_stack_destroy                  ;if we have any t-call returns pending we can't be destroyed
   inc   edx
   cmp   dword [ eax + STACK_EL.prev_esp ], -1
   jne   .err_in_stack_destroy                  ;if we have any f-call returns pending we can't be destroyed
   inc   edx
   cmp   word  [ eax + STACK_EL.next_ss ], STACK_EL.END_OF_CHAIN
   jne   .err_in_stack_destroy                  ;are there any stacks beyond us in the chain?  If so we're in the middle of stack-chain, so can't be destroyed
%endif

   ; -- OK, now find out if we're in a stack chain.  If so we need to be unlinked

   mov      edx, [ eax + STACK_EL.prev_ref ]           ;does anyone point to us?  If not, we can't be in a stack-chain
   test     edx, edx                   ;does EDX contain zero?
   jz       .no_link                   ;if no one has us as their next then we don't need to unlink anything

   xor      edx, edx                   ;better to do EDX than have lots of 32-bit immediates (and nice and RISCy for P6)
   mov      ecx, [ eax + STACK_EL.prev_ptr ]           ;someone points to us; find the address of their stack-element
   mov      [ ecx + STACK_EL.next_ref ], edx           ;set previous's next to zero
   mov   word  [ ecx + STACK_EL.next_ss ], STACK_EL.END_OF_CHAIN      ;also need to set previous's next SS to STACK_EL.END_OF_CHAIN

   ; -- ok, now we need to free our stack-element (i.e. return it to stack_el free list)

.no_link:
   mov      edx, eax                   ;take copy of ptr at our stack element
.retry:
   mov      eax, [ stack_el_fl ]                 ;take local copy of free-list ptr
   mov      [ edx ], eax                     ;mark the element's next pointer as pointing to start of free-list
   cmpxchg  [ stack_el_fl ], edx                 ;point free list at our stack element, thus freeing it
   jne      .retry                        ;however, if free-list changed in mean time, we don't know what's going on so start again.

   ; -- all done as far as destroying this stack goes; carry on with the destruction
   jmp      .stack_destroy_return



%ifdef _DEBUG
.destroy_error:
   pop      ebx
   pop      esi                           ;unstack saved regs
   add      esp, 4
   pop      ecx
   mov      ecx, ORB.XCP_NOREF_TYPE
   jmp      throw_fatal_xcp


.err_in_stack_destroy:

   ; -- OK, we're not at the end of the stack chain.  We need to unwind and throw exception

   add      esp, 8                           ;pop edx and ecx to unwind stack, but they're stacked anyway so who cares?
   pop      eax
   pop      ebx                           ;EBX contains the reference of the failed (stacked at [10])
   pop      esi                           ;unstack saved regs
   add      esp, 4
   pop      ecx
   add      esp, 4                           ;unstack the DS saved at entry-point
   jmp      throw_invalid_xcp


.throw_noref0:
   add      esp, 12
   mov      ecx, ORB.XCP_NOREF_TYPE
   jmp      throw_fatal_xcp

%endif

