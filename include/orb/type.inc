%ifndef __TYPES_INC
%define __TYPES_INC

; -- Some static types

TYPE_REF_DATA     equ   0
TYPE_REF_STACK    equ   3
TYPE_REF_TSS      equ   4

TYPE_PTR_DATA     equ orb_cdt
TYPE_PTR_STACK    equ ( TYPE_REF_STACK * CDT_size + orb_cdt )

%endif
