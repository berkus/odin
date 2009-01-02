; macros to help you time execution of your code

; This macro takes dword temporary variable to store
; temporary timing counter (timing_temp).
;
; start_timing TEMP_VAR

%macro start_timing 1.nolist
%ifdef __TIMING
	push eax
	push edx
	rdtsc
	mov [ %1 ], eax
	pop edx
	pop eax
%endif
%endmacro

; This macro takes timing_temp plus two variables that
; accumulate time used and counter of attempts.
;
; stop_timing TEMP_VAR, TIME, COUNT

%macro stop_timing 3.nolist
%ifdef __TIMING
	push eax
	push edx
	rdtsc		
	sub  eax, [ %1 ]
	add  [ %2 ], eax
	inc  dword [ %3 ]
	pop  edx
	pop  eax
%endif
%endmacro


