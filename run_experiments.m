function [trials,summary]=run_experiments(seeds)
% Matched paired seeds. Random draws per step do not depend on scheduling.
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'src'));
if nargin<1,seeds=[11 23 47];end
out=fullfile(root,'results');if ~exist(out,'dir'),mkdir(out);end
modes={'ideal_periodic','optical_periodic_no_recovery','optical_periodic',...
    'optical_event','optical_event_no_prediction'};
scenarios={'healthy','pointing','body_actuator','attenuation','blockage','combined'};
rows=cell(numel(modes)*numel(scenarios)*numel(seeds),1);h=0;
for a=1:numel(scenarios)
    for b=1:numel(modes)
        for seed=seeds
            c=isc_config(modes{b},scenarios{a},seed);r=isc_run(c);h=h+1;
            rows{h}=struct2table(r.metrics);
            if seed==seeds(1)
                filename=[scenarios{a} '__' modes{b}];
                save(fullfile(out,[filename '.mat']),'r','c','-v7');
                if strcmp(modes{b},'optical_event'),isc_plot(r,c,fullfile(out,[filename '.png']));end
            end
            fprintf('%d/%d %s %s seed=%d RMS=%.3g availability=%.3f\n',...
                h,numel(rows),scenarios{a},modes{b},seed,r.metrics.attitude_rms_rad,r.metrics.link_availability);
        end
    end
end
trials=vertcat(rows{:});writetable(trials,fullfile(out,'trials.csv'));
names=trials.Properties.VariableNames(4:end);
summary=groupsummary(trials,{'scenario','mode'},{'mean','std'},names);
writetable(summary,fullfile(out,'summary.csv'));
save(fullfile(out,'experiment_tables.mat'),'trials','summary');
f=figure('Visible','off','Color','w','Position',[100 100 1250 500]);
tiledlayout(1,2);Y=zeros(6,5);P=Y;
for a=1:6,for b=1:5
    idx=trials.scenario==string(scenarios{a}) & trials.mode==string(modes{b});
    Y(a,b)=mean(trials.attitude_rms_rad(idx))*180/pi;
    P(a,b)=mean(trials.attempted_packets(idx));
end,end
nexttile;bar(Y);xticks(1:6);xticklabels(strrep(scenarios,'_',' '));xtickangle(25);ylabel('Attitude RMS (deg)');grid on;
nexttile;bar(P);xticks(1:6);xticklabels(strrep(scenarios,'_',' '));xtickangle(25);ylabel('Attempted directed packets');grid on;
legend(strrep(modes,'_',' '),'Location','southoutside');
exportgraphics(f,fullfile(out,'comparison.png'),'Resolution',150);close(f);
summarize_fault_windows;
end
