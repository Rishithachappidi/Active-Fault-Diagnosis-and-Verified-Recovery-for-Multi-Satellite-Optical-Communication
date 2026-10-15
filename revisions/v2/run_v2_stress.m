function folder=run_v2_stress
[v,~]=setup_v2;folder=fullfile(v,'results',['stress_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);mkdir(folder);rows=struct([]);
for n=[4 10],for scenario={'pointing','sensor','simultaneous'},for seed=[707 808]
 c=default_config(n);c.scenario=scenario{1};c.seed=seed;c.faultStart=2.7;c.faultEnd=6.7;c.T=11;c.noise=0.2e-6;
 for imp={'v1','v2'}
  r=run_case_v2(c,folder,imp{1});
  row=struct('n',n,'scenario',string(c.scenario),'seed',seed,'implementation',string(imp{1}),...
   'detection_accuracy',r.metrics.detection_accuracy,'isolation_accuracy',r.metrics.isolation_accuracy,...
   'false_positive_rate',r.metrics.false_positive_rate,'uncertain_frequency',r.metrics.uncertain_frequency,...
   'link_outage_s',r.metrics.link_outage_s,'postclear_outage_s',r.extra.postclear_outage_s,...
   'postclear_restoration_verified',r.extra.postclear_restoration_verified);
  if isempty(rows),rows=row;else,rows(end+1)=row;end
  fprintf('STRESS n%d %s seed%d %s postclear %.2f verified %.0f\n',n,c.scenario,seed,imp{1},r.extra.postclear_outage_s,r.extra.postclear_restoration_verified);
 end
end,end,end
writetable(struct2table(rows),fullfile(folder,'stress.csv'));
bdclose('all');
end
