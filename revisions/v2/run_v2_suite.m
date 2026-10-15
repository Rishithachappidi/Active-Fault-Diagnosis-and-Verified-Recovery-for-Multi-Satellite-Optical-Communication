function folder=run_v2_suite(folder)
[v,root]=setup_v2;
if nargin<1,folder=fullfile(v,'results',['comparison_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);mkdir(folder);mkdir(fullfile(folder,'raw'));end
base=fullfile(root,'results','run_20261014_185235_444','raw');rows=struct([]);count=0;
for n=[4 6 8 10]
 for scenario={'normal','pointing','effectiveness','lag','power','blockage','sensor','simultaneous'}
  for seed=[101 202 303 404 505]
   c=default_config(n);c.scenario=scenario{1};c.seed=seed;
   for impl={'v1','v2'}
    implementation=impl{1};id=sprintf('n%d_%s_%s_seed%d',n,c.scenario,implementation,seed);target=fullfile(folder,'raw',[id '.mat']);
    if strcmp(implementation,'v1') && ismember(seed,[101 202])
     saved=load(fullfile(base,sprintf('n%d_%s_proposed_seed%d.mat',n,c.scenario,seed)));r=saved.r;r.extra=v2_extra_metrics(r);origin='preserved_v1';
    elseif isfile(target)
     saved=load(target);r=saved.r;origin='resumed';
    else
     r=run_case_v2(c,fullfile(folder,'raw'),implementation);origin='new_simulink';
    end
    if strcmp(implementation,'v1'),reference=r;
    else
     assert(isequal(reference.config.noiseSamples,r.config.noiseSamples),'Noise not paired');
     assert(isequal(reference.config.edges,r.config.edges),'Topology not paired');
     assert(isequal(reference.D(:,4:8:8*c.m),r.D(:,4:8:8*c.m)),'Fault schedule not paired');
    end
    row=struct('n',n,'scenario',string(c.scenario),'seed',seed,'implementation',string(implementation),'origin',string(origin),'id',string(id));
    fields=fieldnames(r.metrics);for j=1:numel(fields),if ~strcmp(fields{j},'confusion'),row.(fields{j})=r.metrics.(fields{j});end,end
    fields=fieldnames(r.extra);for j=1:numel(fields),row.(fields{j})=r.extra.(fields{j});end
    row.confusion={r.metrics.confusion};
    if isempty(rows),rows=row;else,rows(end+1)=row;end
    count=count+1;fprintf('V2 COMPARISON %d/320 n%d %s seed%d %s [%s]\n',count,n,c.scenario,seed,implementation,origin);
    save(fullfile(folder,'checkpoint.mat'),'rows');
   end
  end
 end
end
T=struct2table(rows);T.confusion=[];writetable(T,fullfile(folder,'all_trials.csv'));
write_json(fullfile(folder,'all_trials.json'),rmfield(rows,'confusion'));
fprintf('V2_RESULT_FOLDER=%s\n',folder);bdclose('all');
end
