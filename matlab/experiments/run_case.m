function r=run_case(c,folder)
c=prepare_config(c);name=sprintf('SatelliteOpticalNetwork_%d',c.n);
load_system(name);
if str2double(get_param([name '/Measurements'],'Inputs'))~=c.m,close_system(name,0);build_models(c);load_system(name);end
mw=get_param(name,'ModelWorkspace');assignin(mw,'cfg',c);
r=struct('id',sprintf('n%d_%s_%s_seed%d',c.n,c.scenario,c.method,c.seed),...
 'config',c,'started',char(datetime('now')),'status','started','software',version);
if nargin>1,save(fullfile(folder,[r.id '_started.mat']),'r');end
tic;out=sim(name);r.runtime=toc;r.t=out.plantLog.Time;
r.Y=timeseries_matrix(out.plantLog);r.D=timeseries_matrix(out.decisionLog);
assert(size(r.Y,2)==26*c.m && size(r.D,2)==8*c.m+4,'Signal dimension mismatch');
assert(all(isfinite(r.Y),'all') && all(isfinite(r.D),'all'),'Nonfinite simulation output');
assert(all(r.Y(:,16:26:end)>=0,'all'),'Negative power');
r.status='completed';r.completed=char(datetime('now'));r.metrics=compute_metrics(r);r.diagnosisEvents=diagnostic_events(r);
if nargin>1,save(fullfile(folder,[r.id '.mat']),'r');write_json(fullfile(folder,[r.id '.json']),rmfield(r,{'Y','D','t','config'}));end
end

