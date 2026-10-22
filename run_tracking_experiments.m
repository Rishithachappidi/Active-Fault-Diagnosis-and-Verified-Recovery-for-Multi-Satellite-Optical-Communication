function trials=run_tracking_experiments
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'src'));
out=fullfile(root,'results','tracking');if ~exist(out,'dir'),mkdir(out);end
if ~isfile(fullfile(out,'pilot.mat')),run_tracking_pilot;end
pilot=load(fullfile(out,'pilot.mat'),'gate');
modes={'ideal_periodic','optical_periodic_no_recovery','optical_periodic','optical_event'};
scenarios={'healthy','pointing','body_actuator','moderate_attenuation',...
    'pointing_actuator','pointing_attenuation','actuator_attenuation','combined','attenuation'};
seeds=[11 23 47];rows={};count=0;
for a=1:numel(scenarios)
    for b=1:numel(modes)
        for seed=seeds
            c=isc_tracking_config(modes{b},scenarios{a},seed,'off');
            [row,count]=execute(c,out,count,108);rows{end+1,1}=row; %#ok<AGROW>
        end
    end
end
main=vertcat(rows{:});writetable(main,fullfile(out,'main_trials.csv'));
management={};
if pilot.gate
    count=0;policies={'schedule','prediction','both'};
    managerScenarios={'healthy','pointing','pointing_actuator','combined','attenuation'};
    for a=1:numel(managerScenarios)
        for b=1:3
            for seed=seeds
                c=isc_tracking_config('optical_event',managerScenarios{a},seed,policies{b});
                [row,count]=execute(c,out,count,45);management{end+1,1}=row; %#ok<AGROW>
            end
        end
    end
end
if ~isempty(management)
    management=vertcat(management{:});writetable(management,fullfile(out,'management_trials.csv'));
    trials=[main;management];
else,trials=main;end
writetable(trials,fullfile(out,'all_trials.csv'));
fields=trials.Properties.VariableNames(5:end);
summary=groupsummary(trials,{'scenario','mode','policy'},{'mean','std'},fields);
writetable(summary,fullfile(out,'summary.csv'));
save(fullfile(out,'tables.mat'),'trials','summary');
isc_tracking_interactions(main,out);
comparison_figure(main,modes,scenarios,out);
fprintf('TRACKING_EXPERIMENTS_PASS: %d trials\n',height(trials));
end
function [row,count]=execute(c,out,count,total)
r=isc_run(c);row=struct2table(r.trackingMetrics);count=count+1;
if c.seed==11
    name=[c.scenario '__' c.mode '__' c.policy];
    save(fullfile(out,[name '.mat']),'r','c','-v7');
    if strcmp(c.mode,'optical_event') && ismember(c.scenario,{'pointing','pointing_actuator','combined'})
        isc_tracking_plot(r,c,fullfile(out,[name '.png']));
    end
end
fprintf('TRACKING %d/%d %s %s %s seed=%d pair=%.5g tracking=%.5g attempts=%d\n',...
    count,total,c.scenario,c.mode,c.policy,c.seed,r.trackingMetrics.fault_pair_rms_rad,...
    r.trackingMetrics.fault_tracking_rms_rad,r.trackingMetrics.attempted_packets);
end
function comparison_figure(trials,modes,scenarios,out)
Y=zeros(numel(scenarios),4);Z=Y;P=Y;
for a=1:numel(scenarios),for b=1:4
    idx=trials.scenario==string(scenarios{a}) & trials.mode==string(modes{b});
    Y(a,b)=mean(trials.fault_pair_rms_rad(idx))*180/pi;
    Z(a,b)=mean(trials.fault_tracking_rms_rad(idx))*180/pi;
    P(a,b)=mean(trials.attempted_packets(idx));
end,end
f=figure('Visible','off','Color','w','Position',[100 100 1550 1100]);
tiledlayout(3,1,'Padding','compact');
nexttile;bar(Y);ylabel('Fault-window pair RMS (deg)');
nexttile;bar(Z);ylabel('Fault-window tracking RMS (deg)');
nexttile;bar(P);ylabel('Attempted directed packets');
for ax=findall(f,'Type','axes')'
    grid(ax,'on');xticks(ax,1:numel(scenarios));xticklabels(ax,strrep(scenarios,'_',' '));xtickangle(ax,15);
end
legend(strrep(modes,'_',' '),'Location','southoutside','NumColumns',4);
exportgraphics(f,fullfile(out,'comparison.png'),'Resolution',130);close(f);
end
