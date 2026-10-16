function int_run_all()
%INT_RUN_ALL  Full integration pipeline, in order.
%   1. run_baselines   both original projects, unmodified
%   2. int_build_model build IntegratedFormationOptical.slx
%   3. int_validate    interface off -> reproduces both baselines
%   4. int_scenarios   S1-S4 plus comparisons, table and figures
%   5. int_tests       15 integration checks (errors if any fail)
here = fileparts(mfilename('fullpath'));
addpath(here);
run_baselines();
int_setup(); int_build_model();
int_validate();
int_scenarios();
int_tests();
end
