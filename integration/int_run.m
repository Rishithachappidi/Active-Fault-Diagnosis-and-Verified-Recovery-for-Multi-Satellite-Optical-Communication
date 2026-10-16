function r = int_run(varargin)
%INT_RUN  Run one integrated scenario and score it with the ORIGINAL metric
%   code of both projects.
%   r = int_run('scenario','pointing','attCase',3,'mode',2,'dist',d)
here = int_setup();
mdl = 'IntegratedFormationOptical';
if ~isfile(fullfile(here, [mdl '.slx'])), int_build_model(); end
S = int_config(varargin{:});
load_system(fullfile(here, [mdl '.slx']));
mw = get_param(mdl, 'ModelWorkspace');
vars = {'Ts','Tend','umax','x0','CASE','cfg','distData','c0','MODE','TAUCPA','TACQ'};
for k = 1:numel(vars), assignin(mw, vars{k}, S.(vars{k})); end
assignin(mw, 'TX', S.tx);

tic; out = sim(mdl); runtime = toc;

% ---------- Project B scoring (unchanged compute_metrics / v2_extra_metrics) ----------
r.config = S.cfg; r.runtime = runtime;
r.t = out.plantLog.Time;
r.Y = timeseries_matrix(out.plantLog);
r.D = timeseries_matrix(out.decisionLog);
r.E = timeseries_matrix(out.estimatorLog);
assert(size(r.Y,2) == 26*S.cfg.m && size(r.D,2) == 8*S.cfg.m + 4, 'Project B signal dimension mismatch');
assert(numel(r.t) == size(r.D,1), 'plant and decision logs are not aligned');
assert(max(abs(diff(r.t) - S.cfg.dt)) < 1e-9, 'Project B log is not at cfg.dt');
r.metrics = compute_metrics(r);
r.extra = v2_extra_metrics(r);

% ---------- Project A scoring (same definitions as sff_run_all) ----------
tA = out.t_log(:);
x = orient(out.x_log, numel(tA));
trg = orient(out.trig_log, []);
out.phi_log = orient(out.phi_log, numel(r.t));
out.resid_log = orient(out.resid_log, numel(r.t));
out.trig_log = trg;
[sd, od] = sff_ref(tA);
win = tA >= S.TACQ & tA < S.Tend;
r.A.t = tA; r.A.sige = zeros(numel(tA), 3, 4); r.A.ome = r.A.sige;
for i = 1:4
    r.A.sige(:,:,i) = x(:, 6*(i-1)+1:6*(i-1)+3) - sd.';
    r.A.ome(:,:,i)  = x(:, 6*(i-1)+4:6*(i-1)+6) - od.';
end
r.A.maxSigmaErr = squeeze(max(vecnorm(r.A.sige(win,:,:), 2, 2), [], 1)).';
r.A.maxOmegaErr = squeeze(max(vecnorm(r.A.ome(win,:,:), 2, 2), [], 1)).';
r.A.ntrig = sum(out.trig_log > 0.5, 1);
r.phi = out.phi_log; r.resid = out.resid_log;
r.S = rmfield(S, 'cfg'); r.opts = S.opts;
w = r.t >= S.TACQ + 1 & r.t < S.Tend;
r.losRMS_urad   = 1e6*sqrt(mean(sum(r.phi(w,1:2).^2, 2)));
r.residRMS_urad = 1e6*sqrt(mean(sum(r.resid(w,1:2).^2, 2)));
close_system(mdl, 0);
end

function v = orient(v, N)
% To Workspace 'Array' logs: return samples in rows.
v = squeeze(v);
if isempty(N), if size(v,1) < size(v,2), v = v.'; end, return, end
if size(v,1) ~= N && size(v,2) == N, v = v.'; end
end
