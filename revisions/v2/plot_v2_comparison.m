function plot_v2_comparison(folder)
[v,root]=setup_v2;T=readtable(fullfile(folder,'all_trials.csv'),'TextType','string');
out=fullfile(folder,'figures');if ~isfolder(out),mkdir(out);end
set(groot,'defaultFigureVisible','off');
methods=["v1","v2"];scenarios=unique(T.scenario);
f=figure('Position',[20 20 1300 850]);tiledlayout(2,3);
fields={'detection_accuracy','isolation_accuracy','false_positive_rate','uncertain_frequency','link_outage_s','postclear_outage_s'};
units={'Detection accuracy','Exact isolation (fault samples)','False-alarm rate (healthy samples)','Uncertain fraction','Affected-link outage (s)','Post-clearance outage (s)'};
for k=1:6
 nexttile;hold on;
 for method=methods
  avg=[];dev=[];
  for n=[4 6 8 10]
   means=zeros(5,1);seeds=[101 202 303 404 505];
   for s=1:5,Q=T(T.n==n&T.implementation==method&T.seed==seeds(s),:);means(s)=mean(Q.(fields{k}),'omitnan');end
   avg(end+1)=mean(means);dev(end+1)=std(means);
  end
  errorbar([4 6 8 10],avg,dev,'-o','DisplayName',method,'LineWidth',1.3);
 end
 xlabel('Satellite count');ylabel(units{k});grid on;legend('Location','best');
end
sgtitle('Matched conditions: V1 versus V2; error bars = SD across five seed-level means');
exportgraphics(f,fullfile(out,'matched_scalability.png'),'Resolution',160);close(f);
f=figure('Position',[20 20 1400 850]);tiledlayout(2,2);
for k=1:4
 nexttile;vals=zeros(numel(scenarios),2);dev=vals;
 for i=1:numel(scenarios),for j=1:2
  Q=T(T.n==4&T.scenario==scenarios(i)&T.implementation==methods(j),:);
  vals(i,j)=mean(Q.(fields{k}),'omitnan');dev(i,j)=std(Q.(fields{k}),'omitnan');
 end,end
 b=bar(categorical(scenarios),vals);hold on;
 for j=1:2,errorbar(b(j).XEndPoints,vals(:,j),dev(:,j),'k.','HandleVisibility','off');end
 ylabel(units{k});grid on;legend(methods,'Location','best');
end
sgtitle('Four-node per-scenario diagnostics; mean and SD of five trials');
exportgraphics(f,fullfile(out,'per_scenario_diagnostics.png'),'Resolution',160);close(f);
f=figure('Position',[20 20 1300 950]);tiledlayout(3,2);
for sc=["pointing","sensor"]
 old=load(fullfile(root,'results','run_20261014_185235_444','raw',sprintf('n4_%s_proposed_seed101.mat',sc)));
 new=load(fullfile(folder,'raw',sprintf('n4_%s_v2_seed101.mat',sc)));
 if sc=="pointing",col=1;else,col=2;end
 nexttile(col);hold on;plot(old.r.t,old.r.Y(:,16)*1e6,'DisplayName','V1');plot(new.r.t,new.r.Y(:,16)*1e6,'DisplayName','V2');yline(new.r.config.sensitivity*1e6,'--','Sensitivity','HandleVisibility','off');xline(new.r.config.faultEnd,':','Fault clears','HandleVisibility','off');
 ylabel('Received power (uW)');xlabel('Time (s)');title(sc);legend;grid on;
 nexttile(col+2);stairs(old.r.t,old.r.D(:,1),'DisplayName','V1');hold on;stairs(new.r.t,new.r.D(:,1),'DisplayName','V2');stairs(new.r.t,new.r.D(:,4),'k--','DisplayName','True class');
 ylabel('Class code');xlabel('Time (s)');legend;grid on;
 nexttile(col+4);plot(old.r.t,old.r.D(:,5)*1e6,'DisplayName','V1');hold on;plot(new.r.t,new.r.D(:,5)*1e6,'DisplayName','V2');xline(new.r.config.faultEnd,':','Fault clears','HandleVisibility','off');
 ylabel('Applied x correction (urad)');xlabel('Time (s)');legend;grid on;
end
sgtitle('Measured recovery and correction rollback; representative matched seed 101');
exportgraphics(f,fullfile(out,'clearance_and_recovery.png'),'Resolution',160);close(f);
% Pooled confusion matrices keep uncertainty as a distinct prediction column.
S=load(fullfile(folder,'checkpoint.mat'));rr=S.rows;
f=figure('Position',[20 20 1200 500]);tiledlayout(1,2);
for j=1:2
 C=zeros(9);for i=1:numel(rr),if rr(i).n==4 && rr(i).implementation==methods(j),C=C+rr(i).confusion{1};end,end
 denom=sum(C,2);Q=C./max(denom,1);nexttile;imagesc(Q,[0 1]);colorbar;xticks(1:9);yticks(1:9);xticklabels(0:8);yticklabels(0:8);
 xlabel('Prediction (7 = uncertain)');ylabel('True class');title(methods(j)+' row-normalized confusion');
 writematrix(C,fullfile(folder,sprintf('confusion_n4_%s.csv',methods(j))));
end
exportgraphics(f,fullfile(out,'confusion_matrices.png'),'Resolution',160);close(f);
end

