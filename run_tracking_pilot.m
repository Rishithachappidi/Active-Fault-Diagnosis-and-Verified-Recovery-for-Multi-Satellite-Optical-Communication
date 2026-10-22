function pilot=run_tracking_pilot
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'src'),fullfile(root,'tests'));
tests=test_tracking;out=fullfile(root,'results','tracking');if ~exist(out,'dir'),mkdir(out);end
modes={'ideal_periodic','optical_periodic_no_recovery','optical_periodic','optical_event'};
parts=cell(4,1);logs=cell(4,1);
for i=1:4
    c=isc_tracking_config(modes{i},'pointing',11);r=isc_run(c);
    parts{i}=struct2table(r.trackingMetrics);logs{i}=r;
    fprintf('PILOT %s pair=%.5g tracking=%.5g availability=%.3f\n',modes{i},...
        r.trackingMetrics.fault_pair_rms_rad,r.trackingMetrics.fault_tracking_rms_rad,r.metrics.affected_link_availability);
end
pilot=vertcat(parts{:});writetable(pilot,fullfile(out,'pilot.csv'));
e=pilot.fault_pair_rms_rad(2)-pilot.fault_pair_rms_rad(1);
trackingEffect=pilot.fault_follower_tracking_rms_rad(2)-pilot.fault_follower_tracking_rms_rad(1);
% Measurable limitation gate, declared before management-policy runs.
gate=e>1e-4 || trackingEffect>1e-4;
fid=fopen(fullfile(out,'management_gate.txt'),'w');
fprintf(fid,'Unrecovered minus ideal fault pair RMS: %.12g rad\n',e);
fprintf(fid,'Unrecovered minus ideal follower tracking RMS: %.12g rad\n',trackingEffect);
fprintf(fid,'Management study justified by measured limitation: %d\n',gate);fclose(fid);
save(fullfile(out,'pilot.mat'),'pilot','logs','tests','gate');
assert(all(isfinite(pilot.fault_pair_rms_rad)),'Pilot did not produce finite metrics');
disp(pilot(:,{'mode','fault_pair_rms_rad','fault_tracking_rms_rad','attempted_packets'}));
end
