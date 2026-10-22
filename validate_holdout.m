function checks=validate_holdout
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'src'),fullfile(root,'tests'));
core=run_tests;tracking=test_tracking;heldout=test_holdout;
c=isc_holdout_config('principal_pointing','optical_event',901,'frozen');c.T=32;
build_model(c);name='IntegratedSatelliteControl';cleanup=onCleanup(@()close_system(name,0)); %#ok<NASGU>
simout=sim(name);data=simout.isc_log.Data;rng(c.seed,'twister');s=isc_init(c);
reference=zeros(round(c.T/c.dt),120);
for k=1:size(reference,1)
    [s,z]=isc_step(s,(k-1)*c.dt,k,c);reference(k,:)=isc_telemetry(z)';
end
checks.live_max_abs_difference=max(abs(data(2:end,:)-reference),[],'all');
assert(checks.live_max_abs_difference<1e-10);
checks.core=core.passed;checks.tracking=tracking.passed;checks.heldout=heldout.passed;checks.parity_seconds=c.T;
% The frozen rule stays experimental; retain the management-off demo default.
mw=get_param(name,'ModelWorkspace');mw.assignin('c',isc_tracking_config);save_system(name,fullfile(root,[name '.slx']));
out=fullfile(root,'results','holdout');if ~exist(out,'dir'),mkdir(out);end
save(fullfile(out,'validation.mat'),'checks','core','tracking','heldout');
fid=fopen(fullfile(out,'validation.txt'),'w');
fprintf(fid,'Core checks: %d\nTracking checks: %d\nHeld-out policy checks: %d\nParity interval: %g s\nMaximum aligned live telemetry difference: %.12g\n',...
    core.passed,tracking.passed,heldout.passed,c.T,checks.live_max_abs_difference);fclose(fid);
disp(checks);disp('HOLDOUT_VALIDATION_PASS');
end
