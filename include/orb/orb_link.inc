EXTERN orb_gdt
EXTERN orb_cdt
EXTERN rev_tbl

EXTERN orb_linear
EXTERN orb_base
EXTERN sel_free
EXTERN max_ref
EXTERN active_stack
EXTERN current_comp
EXTERN stack_el_fl
EXTERN static_ds_size
EXTERN cdt_fl
EXTERN xcp_fl
EXTERN tcall_fl

%ifndef __COMPILE_XCP
EXTERN throw_fatal_xcp
EXTERN throw_invalid_xcp
EXTERN throw_gp_xcp
EXTERN throw_rsc_xcp
EXTERN throw_nomem_xcp
EXTERN throw_noref_xcp
%endif

%ifndef __COMPILE_LOAD_GDT
EXTERN load_gdt
%endif
