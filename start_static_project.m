function start_static_project
% Reproduce the earlier static-reference baseline task.
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'src'));
c=isc_config('optical_event','pointing',11);r=isc_run(c);
save(fullfile(root,'results','demo_static.mat'),'r','c');
isc_plot(r,c,fullfile(root,'results','demo_static.png'));
disp(struct2table(r.metrics));
if license('test','Simulink'),build_model(c);open_system(fullfile(root,'IntegratedSatelliteControl.slx'));end
end
