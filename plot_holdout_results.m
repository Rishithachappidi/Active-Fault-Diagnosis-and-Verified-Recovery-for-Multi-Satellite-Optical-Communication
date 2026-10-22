function plot_holdout_results
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'src'));out=fullfile(root,'results','holdout');
means=readtable(fullfile(out,'means_ci.csv'),'TextType','string');
contrasts=readtable(fullfile(out,'paired_contrasts_ci.csv'),'TextType','string');
cases=["principal_pointing","principal_combined"];
modes=["ideal_periodic","optical_periodic_no_recovery","optical_periodic","optical_event","optical_event"];
policies=["off","off","off","off","frozen"];
f=figure('Visible','off','Color','w','Position',[100 100 1400 650]);tiledlayout(1,2,'Padding','compact');
for k=1:2
    nexttile;v=zeros(1,5);lo=v;hi=v;
    for j=1:5
        row=means(means.case_name==cases(k)&means.mode==modes(j)&means.policy==policies(j)&means.metric=="fault_pair_rms_rad",:);
        v(j)=row.mean;lo(j)=row.ci_low;hi(j)=row.ci_high;
    end
    errorbar(1:5,v,v-lo,hi-v,'o','LineWidth',1.5,'MarkerSize',7);grid on;
    xlim([.5 5.5]);xticks(1:5);xticklabels({'Ideal periodic','Optical no recovery','Recovered periodic','Recovered event','Event frozen'});xtickangle(20);
    ylabel('Fault pair RMS (deg), mean and 95% pointwise bootstrap CI');title(strrep(cases(k),'_',' '));
end
exportgraphics(f,fullfile(out,'principal_ci.png'),'Resolution',140);close(f);
g=contrasts(contrasts.comparison=="frozen_minus_event_off"&contrasts.metric=="fault_pair_rms_rad"&contrasts.scale=="percent",:);
f=figure('Visible','off','Color','w','Position',[100 100 1500 550]);
errorbar(1:height(g),g.mean,g.mean-g.ci_low,g.ci_high-g.mean,'o','LineWidth',1.5);hold on;yline(0,'--');grid on;
xticks(1:height(g));xticklabels(strrep(g.case_name,'_',' '));xtickangle(20);
ylabel('Frozen minus off pair RMS (%), paired mean and 95% CI');
exportgraphics(f,fullfile(out,'policy_transfer_ci.png'),'Resolution',140);close(f);
for policy=["off","frozen"]
    file=['principal_pointing__optical_event__' char(policy) '.mat'];d=load(fullfile(out,file),'r','c');
    isc_tracking_plot(d.r,d.c,fullfile(out,['principal_pointing_' char(policy) '.png']));
end
disp('HELDOUT_FIGURES_PASS');
end
