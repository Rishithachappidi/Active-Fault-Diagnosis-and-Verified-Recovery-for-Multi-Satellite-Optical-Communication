function audit=audit_metrics_v1
[v,root]=setup_v2;base=fullfile(root,'results','run_20261014_185235_444','raw');
rows=struct([]);allconf=zeros(9);faultClasses=0:8;
for n=[4 6 8 10]
 for scenario={'normal','pointing','effectiveness','lag','power','blockage','sensor','simultaneous'}
  for seed=[101 202]
   z=load(fullfile(base,sprintf('n%d_%s_proposed_seed%d.mat',n,scenario{1},seed)));r=z.r;
   m=compute_metrics(r);x=v2_extra_metrics(r);
   fields=fieldnames(m);
   for j=1:numel(fields)
    a=m.(fields{j});b=r.metrics.(fields{j});
    assert(isequaln(a,b),'Metric recomputation changed a preserved value');
   end
   row=struct('n',n,'scenario',string(scenario{1}),'seed',seed,'evaluation_samples',x.total_samples,'fault_samples',x.fault_samples,...
    'tp',x.tp,'tn',x.tn,'fp',x.fp,'fn',x.fn,'exact_correct',x.exact_correct,'uncertain_samples',x.uncertain_samples,...
    'eligible_recovery',isfinite(m.recovery_success),'recovery_success',m.recovery_success);
   if isempty(rows),rows=row;else,rows(end+1)=row;end
   allconf=allconf+m.confusion;
  end
 end
end
T=struct2table(rows);audit=struct('runs',height(T),'evaluation_samples',sum(T.evaluation_samples),'fault_samples',sum(T.fault_samples),...
 'detection_accuracy',(sum(T.tp)+sum(T.tn))/sum(T.evaluation_samples),'precision',sum(T.tp)/(sum(T.tp)+sum(T.fp)),...
 'recall',sum(T.tp)/(sum(T.tp)+sum(T.fn)),'false_alarm_rate',sum(T.fp)/(sum(T.fp)+sum(T.tn)),...
 'exact_isolation',sum(T.exact_correct)/sum(T.fault_samples),'uncertainty_rate',sum(T.uncertain_samples)/sum(T.evaluation_samples),...
 'eligible_recovery_runs',sum(T.eligible_recovery),'successful_recovery_runs',sum(T.recovery_success==1),'confusion',allconf,'status','verified_exactly');
writetable(T,fullfile(v,'results','v1_metric_denominators.csv'));write_json(fullfile(v,'results','v1_metric_audit.json'),audit);
disp(audit);
end
