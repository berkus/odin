;========================================================================================
;
; The ORB public interface
;
;========================================================================================

EXTERN method_ctor
EXTERN method_call
EXTERN method_fcall
EXTERN method_tcall
EXTERN method_xfer
EXTERN method_create
EXTERN method_destroy
EXTERN method_install
EXTERN method_uninstall
EXTERN method_lock
EXTERN method_unlock
EXTERN method_get_stack
EXTERN method_sel2ref
EXTERN method_get_self
EXTERN method_get_type
EXTERN method_set_type
EXTERN method_set_desc
EXTERN method_linear
EXTERN method_fault
EXTERN method_reject
EXTERN method_switch_stacks
EXTERN method_throw
EXTERN method_ret


section .text
bits 32

%macro method 1
   jmp %1
   nop
   nop
   nop
%endmacro

method method_ctor          ;0    0x0   private
method method_call          ;8    0x8   public
method method_fcall         ;16   0x10  public
method method_tcall         ;24   0x18  public
method method_xfer          ;32   0x20  public
method method_create        ;40   0x28  private
method method_destroy       ;48   0x30  private
method method_install       ;56   0x38  private
method method_uninstall     ;64   0x40  private
method method_lock          ;72   0x48  private
method method_unlock        ;80   0x50  private
method method_get_stack     ;88   0x58  public
method method_sel2ref       ;96   0x60  private
method method_get_self      ;104  0x68  public
method method_get_type      ;112  0x70  public
method method_set_type      ;120  0x78  private
method method_set_desc      ;128  0x80  private
method method_linear        ;136  0x88  private
method method_fault         ;144  0x90  private
method method_reject        ;152  0x98  private
method method_switch_stacks ;160  0xA0  private
method method_throw         ;168  0xA8  public
method method_ret           ;176  0xB0  public
