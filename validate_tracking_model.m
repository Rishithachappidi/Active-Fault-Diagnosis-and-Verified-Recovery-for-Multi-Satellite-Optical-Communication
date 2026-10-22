function checks=validate_tracking_model
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'src'),fullfile(root,'tests'));
core=run_tests;tracking=test_tracking;
c=isc_tracking_config('optical_event','pointing',11,'both');c.T=32;
build_model(c);name='IntegratedSatelliteControl';cleanup=onCleanup(@()close_system(name,0)); %#ok<NASGU>
simout=sim(name);data=simout.isc_log.Data;
rng(c.seed,'twister');s=isc_init(c);reference=zeros(round(c.T/c.dt),120);
for k=1:size(reference,1)
    [s,z]=isc_step(s,(k-1)*c.dt,k,c);reference(k,:)=isc_telemetry(z)';
end
checks.max_abs_live_difference=max(abs(data(2:end,:)-reference),[],'all');
assert(checks.max_abs_live_difference<1e-10);
checks.core_checks=core.passed;checks.tracking_checks=tracking.passed;
checks.parity_interval_s=c.T;checks.matlab=version;
% Save the moving-reference default with policy OFF. The policy remains an
% experimental ablation until its measured tradeoff is reviewed.
mw=get_param(name,'ModelWorkspace');mw.assignin('c',isc_tracking_config);
save_system(name,fullfile(root,[name '.slx']));
out=fullfile(root,'results','tracking');if ~exist(out,'dir'),mkdir(out);end
save(fullfile(out,'validation.mat'),'checks','core','tracking');
fid=fopen(fullfile(out,'validation.txt'),'w');
fprintf(fid,'Core checks: %d\nTracking checks: %d\nLive parity interval: %g s\nMaximum aligned telemetry difference: %.12g\nMATLAB: %s\n',...
    core.passed,tracking.passed,c.T,checks.max_abs_live_difference,checks.matlab);fclose(fid);
disp(checks);disp('TRACKING_VALIDATION_PASS');
end
