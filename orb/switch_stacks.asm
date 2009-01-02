;========================================================================================
;
; Stack switching
;
;========================================================================================

GLOBAL method_switch_stacks


%include "orb.inc"
%include "cdt.inc"
%include "orb_link.inc"
%include "type.inc"
%include "stack.inc"


section .text
bits 32

;===================================== SWITCH_STACKS ====================================
; switch stacks from resume_ctx in ECX to newly active stack ref in EBX
;
; input:
;  EBX = ref of stack to become active
;  ECX = ref of out-going stack
;
; output:
;  -
;
method_switch_stacks:
   push     ds
   push     ebx
   push     ecx

   mov      eax, ORB.STATIC_SEL
   mov      ds, eax                  ;Switch to ORB's DS

%ifdef _DEBUG
   cmp      ebx, [ max_ref ]
   jg    .invalid_ref
%endif

   shl      ebx, 5                  ;Gonna use stack in ebx

%ifdef _DEBUG
   cmp   dword [ orb_cdt + ebx + CDT.type_ptr ], TYPE_PTR_STACK ;Make sure we're trying to swap in a stack
   jne   near  .stk_type_error
   mov      ax, [ orb_cdt + ebx + CDT.ds_sel ]     ;Get the stack's segment's selector
   cmp      ax, 0xFFFF
   je near  .type_error1               ;Also, make sure it's a valid ObjRef!
%endif

   ; -- If we get here, all is well - switch dem stacks baby!

   mov      eax, [ orb_cdt + ebx + CDT.stack ]      ;Get a pointer to the in-coming stack-element -> EAX
   mov      ebx, [ active_stack ]                   ;Get out-going stack element -> EBX
   mov      dword [ active_stack ], eax             ;Update active stack pointer to in-coming
   test     ecx, ecx                                ;Was there are resume_ctx passed in?
   jnz      .resume_override                        ;If so, we don't need to work out the resume context...
   mov      ecx, [ current_comp ]                   ;...otherwise the resume ctx becomes the calling component

.resume_override:
   mov      [ ebx + STACK_EL.resume_ctx ], ecx      ;store away interrupted context in out-going stack-element
   mov      eax, [ eax + STACK_EL.resume_ctx ]      ;get in-coming's context into EAX...
   mov      dword [ current_comp ], eax             ;...and set current ObjRef to it

   pop      ecx
   pop      ebx
   pop      ds
   retf

%ifdef _DEBUG

.invalid_ref:
   pop      ecx
   pop      ebx
   add      esp, 4
   xor      edx, edx
   mov      ecx, ORB.XCP_NOREF_TYPE
   jmp      throw_fatal_xcp

.type_error1:
   xor      edx, edx
   inc      edx
   jmp      short .throw_invalid

.stk_type_error:
   mov      edx, 2
;   jmp      short .throw_invalid

.throw_invalid:
   pop      ecx
   pop      ebx
   add      esp, 4
   jmp      throw_invalid_xcp

%endif

