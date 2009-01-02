;========================================================================================
;
; The ORB implementation
;
; Control passing functions (method calling)
;
;========================================================================================

GLOBAL method_call
GLOBAL method_fcall
GLOBAL method_tcall
GLOBAL method_xfer
GLOBAL method_ret
GLOBAL method_throw

; for exception handling
GLOBAL method_call.ds_fault
GLOBAL method_call.cs_fault
GLOBAL method_call.ref2big
GLOBAL method_fcall.ds_fault
GLOBAL method_fcall.stack_fault
GLOBAL method_xfer.ds_fault
GLOBAL method_ret.normal_ds_fault
GLOBAL method_ret.fcall_ret

EXTERN orb_gdt
EXTERN orb_cdt


%define ___COMPILE_ORB_CONSOLE
%include "orb.inc"
%include "cdt.inc"
%include "orb_link.inc"
%include "Console.inc"
%include "debug.inc"
%include "stack.inc"
%include "mt.inc"


section .text
bits 32



;/*-----------------------.
;|  call                  |
;|------------------------'-------------------------------------------------------------.
;| Description: ORB's call method invokes a method of another object.                   |
;|                                                                                      |
;| Input:                                                                               |
;|    EBX = callee ref                                                                  |
;|    ECX = method number                                                               |
;`-------------------------------------------------------------------------------------*/
ALIGN 16
method_call:

   ; -- First off, we get access to ORB's DS, and store away the caller's DS.
   ; Also we shl ebx here as we'll need to later anyway, and we can pair it here.

   mov      edi, ORB.STATIC_SEL                            ;Get ready to access the ORB's data segment                 UV PAIR
   mov      ds, edi                                        ;Set to ORB ds                                              NP

   and      ebx, 0x03FFFFFF                                ;make sure that ebx ain't negative!                         UV
   mov      eax, [ current_comp ]                          ;[*] load caller objref in eax                              UV
   mov      [ current_comp ], ebx
   shl      ebx, 5                                         ;Change the ObjRef into an Index into the CDT               PU
   add      ebx, orb_cdt

   ; -- Now we check that the method number supplied is valid.

.ref2big:                                                  ; may fault here
   inc   dword [ ebx + CDT.call_count ]
   cmp   dword ecx, [ ebx + CDT.mcount ]                   ; compare with max methods number                           UV
   jge   short .invalid_method                             ; branch if no method                                       PV PAIR

   ; -- Need to set tcall_depth to zero, saving old tcall_depth away
   ; Also need to save the outgoing old_limit away too.
   ; We also get the current SS and store away outgoing ESP

   push  dword eax                                         ;push the caller's ObjRef for return-log                    UV dependency
   mov      esi, [ active_stack ]                          ;                                                           UV
   mov      edi, ss                                        ;Get stack segment                                          NP
   push  dword [ esi + STACK_EL.limit ]                    ;push the old limit                                         NP
   push  dword [ esi + STACK_EL.tcall_els ]                ;push the old tcall-private-stack                           NP
                                                           ;Note: above 2 pushes might be cheaper via regs (pairing), but no regs free :-(

   ; -- Incrememnt call depth and dec lock count appropriately

   inc   dword [ esi + STACK_EL.call_depth ]               ;increment the call-depth                                   UV

   ; -- Now we need to set up a few things for our return

   mov   dword [ esi + STACK_EL.tcall_els ], 0             ;zero t-call private-stack                                  UV
   push  dword [ esi + STACK_EL.old_esp   ]
   mov         [ esi + STACK_EL.old_esp   ], esp

   ; -- Now we need to do the stack shrinking.  This means extracting
   ; the old-going limit, and setting the new one.
   ;
   ; 1) Extract old limit and store in stack element
   ; 2) Calc new limit and find stack's CDT entry
   ; 3) Write modified limit to stack's CDT and GDT entries

   add   edi, orb_gdt

   test  byte  [ edi + 6 ], 0x80                           ;Is the stack segment page or byte granularity?
   jnz   short .page_gran                                  ;If it's page gran, we have do quite a lot

   mov      edx, [ edi + 4 ]                               ;get top half of stack's out-going descriptor
   and      edx, 0x000F0000;                               ;extract out limit[19..16]
   mov      dx, [ edi ]                                    ;get limit[15..0] from stack's out-going descriptor
   mov      [ esi + STACK_EL.limit ], edx                  ;Set the old SS.limit                                       UV PAIR

   mov      esi, [ esi + STACK_EL.this_ref ]
   shl      esi, 5
   add      esi, orb_cdt
   lea      edx, [ esp - 1 ]                               ;Move esp - 1 into edx (for new limit)                      UV    PAIR

   mov      [ esi + CDT.descr1 ], dx                       ;write the bottom 16 bits of new limit to CDT descr
   mov      [ edi ], dx                                    ;modify ss.limit  (sp - 1) -> gdt[ ss ].limit[0..15])       UV
   and      byte  [ esi + CDT.descr2 + 2 ], 0xF0           ;wipe out the CDT's old limit [19..16]
   and      byte  [ edi + 6 ], 0xF0                        ;wipe out the GDT's old limit [19..16]
   and      edx, 0x000F0000                                ;extract limit[19..16] (i.e. clear bits 31..20 of original limit)
   or       [ esi + CDT.descr2 ], edx                      ;or in the CDT's new limit[19..16]
   or       [ edi + 4 ], edx                               ;or in the GDT's new limit[19..16]

   sub      edi, orb_gdt
   mov      ss, edi                                        ;reload the stack segment.                                  NP

   ; -- Finally we load the caller's ObjRef into EAX (for server
   ; authentication), get the method table, load callee's DS and
   ; jump into the callee at method's offset.
   ; (note EAX is loaded at [*])

   mov      esi, [ ebx + CDT.mtbl ]

   movzx    edi, word [ fs: esi + MT.methods + ecx * 8 + MT_ENTRY.psize ]
   sub      esp, edi                                       ; effectively push method parameters

.ds_fault:                                                 ;label coz this instr. might fault!
   mov      ds, [ ebx + CDT.ds_sel ]                       ;load target DS                                             NP
.cs_fault:
   jmp far  [ fs : esi + MT.methods + ecx * 8 + MT_ENTRY.start ]  ;jump into according to mt.                          NP


.invalid_method:

   ; Note that the callee's thread count is
   ; always incremented before the mcount check to avoid a "time of check to time of use"
   ; race on the callee's objref.
   ; This means that we need to decr the callee's thread count.

   dec      dword [ ebx + CDT.call_count ]                 ;Decrement callee thread count
   mov      [ current_comp ], eax                          ;Reset current_comp to what it was
   sub      ebx, orb_cdt
   shr      ebx, 5                                         ;target objref in ebx
   mov      edx, 0x88880000                                ;
   mov      dx, bx                                         ;target objref becomes the low half datum
   mov      ecx, ORB.XCP_INVALID_TYPE
   jmp      throw_fatal_xcp

.page_gran:                                                ;FIXME: allow support for stacks > 1M
   cli
   mov   ax, ORB.VIDEO_SEL
   mov   gs, ax
   mov dword [gs:0], 'PLSL'
   mov dword [gs:4], 'TLKL'                                ; print PSTK halt message
   shr      esi, 5
   outdword esi                                            ; stack ref
   jmp short $



;/*-----------------------.
;|  ret                   |
;|------------------------'-------------------------------------------------------------.
;| Description: ORB's ret method returns from a method of another object.               |
;|                                                                                      |
;| Input: none                                                                          |
;| Output: none                                                                         |
;`-------------------------------------------------------------------------------------*/
ALIGN 16
method_ret:

   ; -- First off we load ORB DS, and get out-going SS and DS

   mov      edi, ORB.DYNAMIC_SEL                           ;Get ready to load ORB DS                          UV
   mov      ds, edi                                        ;Switch to ORB DS                                  NP

   ; -- Now see if we have calls / tcalls on this stack -- if not we're
   ; returning from fcall.  Also find out caller's ref

   mov   ecx, [ active_stack ]                             ;Get addr of active stack_el -> ecx                UV
   mov   ebx, [ current_comp ]                             ;Get ref of callee -> ebx                          UV PAIR
   cmp   dword [ ecx + STACK_EL.call_depth ], 0            ;have we any calls or t-calls?                     PU
   jne   .not_fcall_ret                                    ;If so, go deal with 'em, else we have an fcall    PV PAIR

   ; -- We know we have fcall ret if call depth and tcall depth are both zero

.fcall_ret:
   lss      esp, [ ecx + STACK_EL.prev_esp ]               ;restore SS:ESP                                    NP
   shl      ebx, 5                                         ;need to index callee's CDT                        PU
   pop      esi                                            ;get in-coming ref                                 UV PAIR
   mov      edi, [ ecx + STACK_EL.prev_ptr ]               ;find out previous stack-el                        UV
   mov      [ current_comp ], esi                          ;remember it                                       UV PAIR
   mov      ecx, [ orb_cdt + ebx + CDT.cs_sel ]            ;                                                  UV
   shl      esi, 5                                         ;                                                  PU WAR
   mov      [ active_stack ], edi                          ;change active_stack                               UV PAIR
   dec      dword [ orb_cdt + ebx + CDT.call_count ]       ;decrement out-going component's call-count        UV PAIR
   mov      [ esp + 4 ], ecx                               ;re-instate return CS                              UV
                                                           ;[NOTE: no race, because CS cannot change once current_comp has been set]
   mov      ds, [ orb_cdt + esi + CDT.ds_sel ]             ;restore caller DS                                 NP
   retf                                                    ;return to sender                                  NP


   ; -- We are returning from a call or a tcall.

.not_fcall_ret:
   shl   ebx, 5                                            ;need to index callee's CDT                        PU
   dec   dword [ orb_cdt + ebx + CDT.call_count ]
   cmp   dword [ ecx + STACK_EL.tcall_els ], 0             ;do we have a private t-call stack?                UV
   je    short .call_ret                              ;if tcall depth = 0 now, then we're returning from call PV PAIR


   ; -- We know here we're returning from an tcall here.

.tcall_ret:

   ; First of all unlink the stack element.

   mov      edi, [ ecx + STACK_EL.tcall_els ]              ;get private call-stack base                       UV
   dec      dword [ ecx + STACK_EL.call_depth ]            ;Decrement call_depth                              UV PAIR
   mov      ebx, [ edi + TCALL_EL.next ]                   ;get private stack->next                           UV
   mov      [ ecx + STACK_EL.tcall_els ], ebx              ;unlink the element                                UV RAW dep

   ; Get return cs (lock it in the GDT), and offs -- putting on stack

   mov      ebx, [ edi + TCALL_EL.ret_ref ]                ;get the return ObjRef                             UV
   mov      [ current_comp ], ebx                          ;place the return ObjRef in current_comp
   shl      ebx, 5                                         ;prepare to index the CDT with ebx                 PU
   mov      si, [ orb_cdt + ebx + CDT.cs_sel ]             ;load in the CS's ObjRef                           UV AGI
   push     esi                                            ;push the return segment                           UV
   mov      ecx, [ edi + TCALL_EL.ret_offs ]               ;get return offset                                 UV WAR dep?
   push     ecx                                            ;push the return offset                            UV

   ; -- Free the private call-stack element

   mov      esi, eax                                       ;save eax (can't use ebx for cmpxchg)              UV
.free_el:
   mov      eax, [ tcall_fl ]                              ;get start of 16-byte free-list                    UV
   mov      [ edi + TCALL_EL.next ], eax                   ;point old_el->next at start of free-list          UV
   cmpxchg  [ tcall_fl ], edi                              ;put old_el at front of free-list (atomically)     NP
   jne      .free_el                                       ;if atomic 'free' failed, retry                    PV

   mov      eax, esi                                       ;restore eax                                       UV PAIR

   ; -- Get return ds and lock it in the GDT before returning

.tret_ds_fault:                                            ;label -- next might fault
   mov      ds, [ orb_cdt + ebx + CDT.ds_sel ]             ;load in DS                                        NP
.tret_fault:                                               ;label -- ret might fault if CS wasn't cached in GDT
   retf                                                    ;                                                  NP


   ; -- We know here we're returning from a call.

.call_ret:

   ; -- Now re-grow the stack
   ;  ESI = stack's old limit
   ;  EDX = SS
   ;  EBX = desc2
   ;  EDI = incoming_limit

   mov      esi, [ ecx + STACK_EL.this_ref ]               ;Get SS's ObjRef                                   NP
   shl      esi, 5
   push     edx                                            ;preserve EDX for return value
   mov      edx, ss                                        ;Get out-going SS                                  NP
   mov      edi, [ ecx + STACK_EL.limit ]                  ;Get the old SS.limit                              UV PAIR
   mov      [ orb_cdt + esi + CDT.descr1 ], di
   mov      [ orb_gdt + edx ], di                          ;Reset old SS.limit[15..0]                         UV PAIR

   mov      ebx, [ orb_cdt + esi + CDT.descr2 ]            ;get upper stack descr                             UV
   and      ebx, 0xFFF0FFFF                                ;we don't change descr2 apart from limit[19..16]   UV
   and      edi, 0x000F0000                                ;Extract limit[19..16] from EDI                    UV
   or       ebx, edi                                       ;Build the new descr2 in EBX
   mov      [ orb_cdt + esi + CDT.descr2 ], ebx            ;Move new descr2 into CDT                          UV
   mov      [ orb_gdt + edx + 4 ], ebx                     ;Move new descr2 into GDT                          UV

   mov      ss, edx                                        ;Reload the stack segment                          NP
   pop      edx                                            ;get EDX back for return value
   mov      esp, [ ecx + STACK_EL.old_esp ]

   pop   dword [ ecx + STACK_EL.old_esp ]                  ;FIXME: Are we better off storing the descriptor??
   dec   dword [ ecx + STACK_EL.call_depth ]               ;Decrement call_depth
   pop   dword [ ecx + STACK_EL.tcall_els ]                ;Set the incoming tcall private-stack              NP
   pop   dword [ ecx + STACK_EL.limit ]                    ;Set the incoming old_limit                        NP

   ; -- Reset ds, and return to sender

   pop      ebx                                            ;Get the stacked objref                            UV
   mov      [ current_comp ], ebx
   shl      ebx, 5
   mov      ecx, [ orb_cdt + ebx + CDT.cs_sel ]            ;                                                  UV
   mov      [ esp + 4 ], ecx                               ;re-instate return CS                              UV RAW
                                                           ; [NOTE: no race, because CS cannot change once current_comp has been set]
.normal_ds_fault:
   mov      ds, [ orb_cdt + ebx + CDT.ds_sel ]             ;set caller's DS                                   NP
.normal_cs_fault:
   retf                                                    ;and return to caller... all done!                 NP



;/*-----------------------.
;|  fcall                 |
;|------------------------'-------------------------------------------------------------.
;| Description: ORB's fcall method invokes a method of another object                   |
;|              via fast-call mechanism.                                                |
;|                                                                                      |
;| Input:                                                                               |
;|    EBX = callee ref                                                                  |
;|    ECX = method number                                                               |
;`-------------------------------------------------------------------------------------*/
ALIGN 16
method_fcall:

   ; -- First off, we get access to ORB's DS, and store away the caller's DS.
   ; Also we shl ebx here as we'll need to later anyway, and we can pair it here.

   mov      edi, ORB.STATIC_SEL                            ;Get ready to access the ORB's data segment        UV
   and      ebx, 0x03FFFFFF                                ;make sure ebx ain't negative                      UV PAIR
   mov      ds, edi                                        ;Set to ORB ds                                     NP
   mov      eax, [ current_comp ]                          ;Get out-going ref-> EAX                           UV
   mov      edx, [ active_stack ]                          ;what's the active-stack                           UV PAIR

   push     eax                                            ;remember the caller                               UV
   shl      ebx, 5                                         ;Change the ObjRef into an Index into the CDT      PU
   mov      esi, [ edx + STACK_EL.next_ptr ]               ;get the next stack-el                             UV PAIR

   ; -- Increment the callee's thread_count and store away outgoing esp
   ; these two unlrelated ops are together for pairing.  Note that we
   ; increment call count before mcount check to avoid a "time of
   ; check to time of use" race on the mcount (mcount might change
   ; through destruction and subsequent re-use of objref)

   inc   dword [ orb_cdt + ebx + CDT.call_count ]          ;incrememnt in-coming's call-count
   mov   [ esi + STACK_EL.prev_esp ], esp                  ;save away outgoing esp                            UV PAIR

   ; -- Now we check that the method number supplied is valid.
   ; We also get the current SS and store away outgoing ESP

   cmp   dword ecx, [ orb_cdt + ebx + CDT.mcount ]       ;make sure requested method number was within range. UV
   jge   .invalid_method                                   ;branch if no method                               PV PAIR

   ; -- Now we load the next stack segment in the f-call `stack chain'
   ;We also load the ESP from the stack chain's limit

.stack_fault:                                              ;may fault
   lss      esp, [ edx + STACK_EL.next_esp ]               ;get in-coming SS:ESP                              NP
   mov      [ active_stack ], esi                          ;switch to new active stack-el ptr                 UV

   ; -- Finally we load the caller's ObjRef into EAX (for server
   ; authentication), get the method table, load callee's DS and
   ; jump into the callee at method's offset.

   mov      edx, [ orb_cdt + ebx + CDT.mtbl ]              ;load the method table pointer                     UV PAIR
.ds_fault:                                                 ;label coz this instr. might fault!
   mov   word  ds, [ orb_cdt + ebx + CDT.ds_sel ]          ;load target DS                                    NP
                                                           ; FIXME: is fcall CS faultless???
   jmp far  [ fs : edx + MT.methods + ecx * 8 + MT_ENTRY.start ]  ;jump into accourding to mt.                NP

.invalid_method:

   ; -- Note that the callee's thread count is
   ; always incremented before the mcount check to avoid
   ; a "time of check to time of use" race on the callee's objref.
   ; This means that we need to decr the callee's thread count.

   dec      dword [ orb_cdt + ebx + CDT.call_count ]       ;Decrement callee thread count
   pop      eax
   shr      ebx, 5                                         ;target objref in ebx
   mov      edx, ebx
   mov      ecx, ORB.XCP_INVALID_TYPE
   jmp      throw_fatal_xcp



;/*-----------------------.
;|  tcall                 |
;|------------------------'-------------------------------------------------------------.
;| Description: ORB's tcall method invokes a method of another object                   |
;|              via trusted-call mechanism.                                             |
;|                                                                                      |
;| Input:                                                                               |
;|    EBX = callee ref                                                                  |
;|    ECX = method number                                                               |
;`-------------------------------------------------------------------------------------*/
ALIGN 16
method_tcall:

   ; -- First off, we get access to ORB's DS, and store away the caller's DS
   ; Also we shl ebx here as we'll need to later anyway, and we can pair it here.

   mov      edi, ORB.DYNAMIC_SEL                           ;Get ready to access the ORB's data segment        UV
   mov      ds, edi                                        ;Set to ORB ds                                     NP
   mov      edi, [ active_stack ]                          ;                                                  UV
   mov      esi, [ current_comp ]                          ;                                                  UV PAIR

   ; -- Check that target objref is ok

   cmp      dword ebx, [ max_ref ]
   jle      short .ref_ok

   mov      edx, 0x333                                     ; FIXME: BOGUS MAGIC
   jmp      throw_noref_xcp

.ref_ok:
   mov      [ current_comp ], ebx                          ;                                                  UV
   shl      ebx, 5                                         ;Change the ObjRef into an Index into the CDT      PU
   inc      dword [ orb_cdt + ebx + CDT.call_count ]       ;incrememnt callee's thread count (means that it   NP
                                                           ;will become zombie if destroyed, avoiding race)

   ; -- Now check mcount is ok, increment tcall depth, get target addr

   cmp   dword ecx, [ orb_cdt + ebx + CDT.mcount ]         ;Make sure method number is OK                     UV
   jge   short .invalid_method                             ;                                                  PV PAIR

   ; -- Get an element off the free list 16 for stack

.get_priv_stack:
   mov      eax, [ tcall_fl ]                              ;pluck next element off the free-list              UV
   mov      edx, [ eax + TCALL_EL.next ]                   ;find next element of free-list  (pre-fetch)       UV PAIR     note: might be fetching 0 + PRIV_STACK_NEXT, but that's not a prob
   test     eax, eax                                       ;don't change EAX, but set flags                   UV
   jz       short .no_mem                                  ;if not, we're in trouble...                       PV PAIR

   cmpxchg  [ tcall_fl ], edx                              ;make that the first (unless the lists's changed)  NP !SLOW!
   mov      edx, [ edi + STACK_EL.tcall_els ]           ;get stack segment's private stack -> edx (pre-fetch) UV
   jne      .get_priv_stack                                ; - if list changed, retry operation               PV PAIR

   ; -- link the newly allocated element into the call-stack

   mov      [ eax + TCALL_EL.next ], edx                   ;point new element->next at current call-stack     UV
   mov      [ edi + STACK_EL.tcall_els ], eax              ;make call-stack start at new element              UV PAIR

   ; -- Now we need to set up the members of the new call-stack element

   pop   dword [ eax + TCALL_EL.ret_offs ]                 ;pop return addr.offset into private stack         NP
   inc   dword [ edi + STACK_EL.call_depth ]               ;need to increment the call depth too!             UV
   pop   dword edi                                         ;pop return code seg                               UV PAIR
   mov   [ eax + TCALL_EL.ret_ref ], esi                   ;put return comp on private stack                  UV PAIR

   ; -- Now do the call.  We need to set new ds, save old one, and
   ; jump into the component as specified in method table.

   mov      esi, [ orb_cdt + ebx + CDT.mtbl ]              ;load the method table pointer                     UV PAIR
.tcall_fault:                                              ;label coz this instr. might fault!
   mov      ds, [ orb_cdt + ebx + CDT.ds_sel ]             ;load target DS                                    NP
                                                           ;FIXME: is tcall CS faultless???
   jmp far  [ fs : esi + MT.methods + ecx * 8 + MT_ENTRY.start ]  ;jump into accourding to mt.                NP

   ; -- Handle any errors.

.no_mem:
   push  dword TCALL_EL_size                               ;We need TCALL_EL_size bytes
   push  dword .get_priv_stack                             ;This is (sort of) the address that faulted
   call  throw_nomem_xcp                                   ;Throw it
   add   esp, 8
   jmp   .get_priv_stack                                   ;retry the claim private stack op

.invalid_method:

   ; -- Note that the callee's thread count is always incremented before
   ; the mcount check to avoid a "time of check to time of use" race on the callee's objref.
   ; This means that we need to decr the callee's thread count.

   dec      dword [ orb_cdt + ebx + CDT.call_count ]       ;Decrement callee thread count
   mov      [ current_comp ], esi                          ;Reset current_comp to what it was
   shr      ebx, 5                                         ;target objref in ebx
   mov      edx, ebx                                       ;target objref becomes the datum
   mov      ecx, ORB.XCP_INVALID_TYPE
   jmp      throw_fatal_xcp



;/*-----------------------.
;|  xfer                  |
;|------------------------'-------------------------------------------------------------.
;| Description: ORB's xfer method invokes a method of another object                    |
;|              without recording in-coming return address.                             |
;|                                                                                      |
;| Input:                                                                               |
;|    EBX = callee ref                                                                  |
;|    ECX = method number                                                               |
;`-------------------------------------------------------------------------------------*/
ALIGN 16
method_xfer:

   ; -- Switch to ORB's DS, and shift left ebx to take advantage of pairing.
   ; Also get callee ObjRef

   and      ebx, 0x03FFFFFF                                ;                                                  UV
   mov      eax, ORB.STATIC_SEL                            ;Prepare to switch to ORB DS                       UV PAIR
   mov      ds, eax                                        ;Switch to ORB DS                                  NP
   mov      eax, [ current_comp ]                          ;get out-going reference                           UV
   mov      [ current_comp ], ebx                          ;remember the in-coming one                        UV RAW dep
   shl      ebx, 5                                         ;Get cdt offset from ObjRef                        PU
   mov      edx, eax                                       ;                                                  UV PAIR
   shl      edx, 5                                         ;get ready to reference out-going's CDT            PU

   inc   dword [ orb_cdt + ebx + CDT.call_count ]          ;incr in-coming's call count                       UV PAIR

   cmp   dword ecx, [ orb_cdt + ebx + CDT.mcount ]         ;Make sure method number is OK                     UV
   jge   short .invalid_method                             ;                                                  PV PAIR

   mov   esi, [ orb_cdt + ebx + CDT.mtbl ]                 ;Get MT pointer                                    UV

   dec   dword [ orb_cdt + edx + CDT.call_count ]          ;decr out-going call count                         UV PAIR? apparently not :-(

.ds_fault:
   mov   ds, [ orb_cdt + ebx + CDT.ds_sel ]                ;Get target DS.                                    NP
                                                           ; FIXME: is xfer CS faultless???
   jmp   far  [ fs : esi + MT.methods + ecx * 8 + MT_ENTRY.start ]  ;jump into according to mt.               NP

.invalid_method:

   ; -- Note that the callee's thread count is always incremented before the mcount
   ; check to avoid a "time of check to time of use" race on the callee's objref.
   ; This means that we need to decr the callee's thread count.

   dec   dword [ orb_cdt + ebx + CDT.call_count ]          ;Decrement callee thread count
   mov   [ current_comp ], eax                             ;Reset current_comp to what it was
   shr   ebx, 5                                            ;target objref in ebx
   mov   edx, ebx                                          ;target objref becomes the datum
   mov   ecx, ORB.XCP_INVALID_TYPE
   jmp   throw_fatal_xcp



;/*-----------------------.
;|  throw                 |
;|------------------------'-------------------------------------------------------------.
;| Description: ORB's throw throws specified exception by invoking ORB-specific         |
;|              exception interrupt vector XCP_INT_VEC.                                 |
;|                                                                                      |
;| Input: FIXME                                                                         |
;| Output: FIXME                                                                        |
;`-------------------------------------------------------------------------------------*/
ALIGN 16
method_throw:

   ; -- First off we load ORB DS, and get out-going SS and DS

   mov      edi, ORB.DYNAMIC_SEL                           ;Get ready to load ORB DS                          UV
   mov      ds, edi                                        ;Switch to ORB DS                                  NP

   ; -- Now see if we have calls / tcalls on this stack - if not we're
   ; returning from fcall.  Also find out caller's ref

   mov   edx, [ current_comp ]                             ;Get ref of callee -> edx                          UV
   shl   edx, 5                                            ;need to index callee's CDT                        PU
   mov   ecx, [ active_stack ]                             ;Get addr of active stack_el -> ecx                UV PAIR
   cmp   dword [ ecx + STACK_EL.call_depth ], 0            ;have we any calls or t-calls?                     PU
   jne   short .not_fcall_ret                              ;If so, go deal with 'em, else we have an fcall    PV PAIR

   ; -- We know we have fcall ret if call depth and tcall depth are both zero

.fcall_ret:
   lss      esp, [ ecx + STACK_EL.prev_esp ]               ;restore SS:ESP                                    NP
   mov      edi, [ ecx + STACK_EL.prev_ptr ]               ;find out previous stack-el                        UV PAIR  [ Apparently not :-( ]
   mov      [ active_stack ], edi                          ;change m_active_stack                             UV
   pop      ebx                                            ;get in-coming ref

.throw_it:
   pop      ecx                                            ;place the offset we would have returned to in ecx
   add      esp, 4                                         ;'pop' the code segment to return to.
   int      ORB.XCP_INT_VEC


.not_fcall_ret:

   ; -- We are returning from a call or a tcall.

   mov   esi, ss                                           ;Get out-going SS                                  NP
   cmp   dword [ ecx + STACK_EL.tcall_els ], 0             ;do we have a private t-call stack?                UV
   je    short .call_ret                              ;if tcall depth = 0 now, then we're returning from call PV PAIR


.tcall_ret:

   ; -- We know here we're returning from an tcall here.
   ; First of all unlink the stack element

   mov      edi, [ ecx + STACK_EL.tcall_els ]              ;get private call-stack base                       UV
   dec      dword [ ecx + STACK_EL.call_depth ]            ;Decrement call_depth                              UV PAIR
   mov      edx, [ edi + TCALL_EL.next ]                   ;get private stack->next                           UV
   mov      [ ecx + STACK_EL.tcall_els ], edx              ;unlink the element                                UV RAW dep

   ; -- Get return cs (lock it in the GDT), and offs - putting on stack

   mov      ebx, [ edi + TCALL_EL.ret_ref ]                ;get the return ObjRef                             UV
   shl      ebx, 5                                         ;                                                  PU
   
   ;FIXME: commented in Greg's code
   ;inc  dword [ orb_cdt + edx + CDT.gdt_lock ]            ;lock return CS in GDT                             UV
   
   mov      dx, word [ orb_cdt + ebx + CDT.cs_sel ]        ;load in the CS's ObjRef                           UV
   push     edx                                            ;push the return segment                           UV
   mov      edx, [ edi + TCALL_EL.ret_offs ]               ;get return offset                                 UV
   push     edx                                            ;push the return offset                            UV
   shr      ebx, 5                                         ;put ebx back to the return ref

   ; -- Free the private call-stack element

   mov      edx, [ edi + TCALL_EL.ret_ref ]                ;get the DS ObjRef before we free the element      UV
   
   mov      esi, eax                                       ;save eax (can't use edx for cmpxchg)              UV
.free_el:
   mov      eax, [ tcall_fl ]                              ;get start of 16-byte free-list                    UV
   mov      [ edi + TCALL_EL.next ], eax                   ;point old_el->next at start of free-list          UV
   cmpxchg     [ tcall_fl ], edi                           ;put old_el at front of free-list (atomically)     NP
   jne      .free_el                                       ;if atomic 'free' failed, retry                    PV

   mov      eax, esi                                       ;restore eax                                       UV
   jmp      .throw_it

   ; -- We know here we're returning from a call.

.call_ret:

   ; -- Now re-grow the stack

   mov      esi, [ ecx + STACK_EL.this_ref ]               ;Get SS's ObjRef                                   NP
   shl      esi, 5
   mov      edx, ss                                        ;Get out-going SS                                  NP
   mov      edi, [ ecx + STACK_EL.limit ]                  ;Get the old SS.limit                              UV PAIR
   mov      [ orb_cdt + esi + CDT.descr1 ], di
   mov      [ orb_gdt + edx ], di                          ;Reset old SS.limit[15..0]                         UV PAIR

   mov      ebx, [ orb_cdt + esi + CDT.descr2 ]            ;get upper stack descr                             UV
   and      ebx, 0xFFF0FFFF                                ;we don't change descr2 apart from limit[19..16]   UV
   and      edi, 0x000F0000                                ;Extract limit[19..16] from EDI                    UV
   or       ebx, edi                                       ;Build the new descr2 in EBX
   mov      [ orb_cdt + esi + CDT.descr2 ], ebx            ;Move new descr2 into CDT                          UV
   mov      [ orb_gdt + edx + 4 ], ebx                     ;Move new descr2 into GDT                          UV

   mov      ss, edx                                        ;Reload the stack segment                          NP
   mov      esp, [ ecx + STACK_EL.old_esp ]
   pop      dword [ ecx + STACK_EL.old_esp ]
   dec      dword [ ecx + STACK_EL.call_depth ]            ;Decrement call_depth
   pop      dword [ ecx + STACK_EL.tcall_els ]             ;Set the incoming tcall private-stack              NP
   pop      dword [ ecx + STACK_EL.limit ]                 ;Set the incoming old_limit                        NP

   ; -- Reset ds, and return to sender

   pop      ebx                                            ;Get the stacked objref                            UV
   jmp      .throw_it


;========================================================================================
; EOF
;========================================================================================
