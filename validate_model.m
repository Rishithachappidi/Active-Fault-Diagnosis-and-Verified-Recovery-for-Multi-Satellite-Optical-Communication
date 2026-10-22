function checks=validate_model
% Validate live Simulink/standalone equivalence and numerical sensitivity.
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'src'));
build_model;name='IntegratedSatelliteControl';
cleanup=onCleanup(@()close_system(name,0)); %#ok<NASGU>
c=isc_config('optical_event','pointing',11);c.T=2;
mw=get_param(name,'ModelWorkspace');mw.assignin('c',c);
simout=sim(name);data=simout.isc_log.Data;
rng(c.seed,'twister');s=isc_init(c);
reference=zeros(round(c.T/c.dt),120);
for k=1:size(reference,1)
    [s,z]=isc_step(s,(k-1)*c.dt,k,c);reference(k,:)=isc_telemetry(z)';
end
assert(isequal(size(data),[size(reference,1)+1,120]),'Unexpected telemetry shape');
checks.simulink_max_abs_difference=max(abs(data(2:end,:)-reference),[],'all');
assert(checks.simulink_max_abs_difference<1e-10,'Live model differs from standalone core');
% Reset the model's saved default after the temporary smoke configuration.
mw.assignin('c',isc_config);save_system(name,fullfile(root,[name '.slx']));
c=isc_config('optical_event','pointing',11);r=isc_run(c);
fine=c;fine.dt=c.dt/2;fine.fitSamples=round(fine.fitWindow/fine.dt);
fine.decisionSteps=round(0.2/fine.dt);rf=isc_run(fine);
checks.coarse_rms_rad=r.metrics.attitude_rms_rad;
checks.fine_rms_rad=rf.metrics.attitude_rms_rad;
checks.rms_abs_difference_rad=abs(checks.coarse_rms_rad-checks.fine_rms_rad);
checks.coarse_affected_availability=r.metrics.affected_link_availability;
checks.fine_affected_availability=rf.metrics.affected_link_availability;
assert(checks.rms_abs_difference_rad<5e-4,'Unexpectedly large step sensitivity');
% Fault-clearance recovery must remove a stale optical correction.
late=r.t>=70;
checks.post_clearance_max_correction_rad=max(abs(r.correction(late,:,1:2)),[],'all');
assert(checks.post_clearance_max_correction_rad<.1*c.divergence);
checks.post_clearance_availability=mean(r.up(late,1:2),'all');
assert(checks.post_clearance_availability>.95);
checks.matlab=version;save(fullfile(root,'results','model_validation.mat'),'checks');
fid=fopen(fullfile(root,'results','model_validation.txt'),'w');
fprintf(fid,'MATLAB %s\n',checks.matlab);
fields=fieldnames(checks);
for h=1:numel(fields)
    if isnumeric(checks.(fields{h})),fprintf(fid,'%s: %.12g\n',fields{h},checks.(fields{h}));end
end
fclose(fid);disp(checks);disp('LIVE_MODEL_PARITY_AND_CLEARANCE_PASS');
end
