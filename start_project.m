function start_project
% START_PROJECT Run the integrated demonstration and open its Simulink model.
root=fileparts(mfilename('fullpath')); addpath(fullfile(root,'src'));
out=fullfile(root,'results'); if ~exist(out,'dir'), mkdir(out); end
c=isc_tracking_config('optical_event','pointing',11,'off');
r=isc_run(c); save(fullfile(out,'demo.mat'),'r','c');
isc_tracking_plot(r,c,fullfile(out,'demo.png'));
disp(struct2table(r.trackingMetrics));
if license('test','Simulink')
    build_model(c); open_system(fullfile(root,'IntegratedSatelliteControl.slx'));
end
end
