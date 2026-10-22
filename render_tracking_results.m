function render_tracking_results
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'src'));
out=fullfile(root,'results','tracking');files=dir(fullfile(out,'*__optical_event__*.mat'));
for k=1:numel(files)
    d=load(fullfile(files(k).folder,files(k).name),'r','c');r=d.r;c=d.c;
    if ismember(c.scenario,{'pointing','pointing_actuator','combined'})
        [~,stem]=fileparts(files(k).name);isc_tracking_plot(r,c,fullfile(out,[stem '.png']));
    end
end
d=load(fullfile(out,'pointing__optical_event__off.mat'),'r','c');r=d.r;c=d.c;
save(fullfile(root,'results','demo.mat'),'r','c');
isc_tracking_plot(r,c,fullfile(root,'results','demo.png'));
build_model(c);print('-sIntegratedSatelliteControl','-dpng','-r120',fullfile(root,'results','simulink_architecture.png'));
close_system('IntegratedSatelliteControl',0);disp('TRACKING_FINAL_RENDER_PASS');
end
