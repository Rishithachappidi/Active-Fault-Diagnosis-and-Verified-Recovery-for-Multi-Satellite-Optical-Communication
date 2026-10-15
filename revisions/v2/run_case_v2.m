function r=run_case_v2(c,folder,implementation)
if nargin<3,implementation='v2';end
setup_v2;c=prepare_config(c);
if strcmp(implementation,'v2'),name=sprintf('SatelliteOpticalNetwork_%d_v2',c.n);
else,name=sprintf('SatelliteOpticalNetwork_%d',c.n);end
load_system(name);mw=get_param(name,'ModelWorkspace');assignin(mw,'cfg',c);
r=struct('id',sprintf('n%d_%s_%s_seed%d',c.n,c.scenario,implementation,c.seed),...
 'config',c,'implementation',implementation,'started',char(datetime('now')),'status','started','software',version);
if nargin>1 && ~isempty(folder)
 assert(~isfile(fullfile(folder,[r.id '.mat'])),'Refusing to overwrite a completed trial');
 save(fullfile(folder,[r.id '_started.mat']),'r');
end
tic;out=sim(name);r.runtime=toc;r.t=out.plantLog.Time;
r.Y=timeseries_matrix(out.plantLog);r.D=timeseries_matrix(out.decisionLog);
if strcmp(implementation,'v2'),r.E=timeseries_matrix(out.estimatorLog);assert(all(isfinite(r.E),'all'));end
assert(size(r.Y,2)==26*c.m && size(r.D,2)==8*c.m+4);
assert(all(isfinite(r.Y),'all') && all(isfinite(r.D),'all'));
r.status='completed';r.completed=char(datetime('now'));
r.metrics=compute_metrics(r);r.extra=v2_extra_metrics(r);
if nargin>1 && ~isempty(folder)
 save(fullfile(folder,[r.id '.mat']),'r');
 omit={'Y','D','t','config'};if isfield(r,'E'),omit{end+1}='E';end
 write_json(fullfile(folder,[r.id '.json']),rmfield(r,omit));
end
end
