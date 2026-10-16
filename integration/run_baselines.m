function B = run_baselines()
%RUN_BASELINES  Record both unmodified baselines before/after integration.
%   Project A: sff_run_all (Simulink model sff_ets_model, cases 1-3).
%   Project B: one V2 Simulink trial (n4, pointing, seed 101) compared with
%              the saved record in the committed comparison batch.
here = fileparts(mfilename('fullpath'));
root = fileparts(here);
out  = fullfile(here, 'results'); if ~isfolder(out), mkdir(out); end

% ---------------- Project A ----------------
addpath(fullfile(here, 'projectA'));
old = cd(fullfile(here, 'projectA'));
cleanup = onCleanup(@() cd(old));
R = sff_run_all();
P = sff_params();
A = struct('ntrig', vertcat(R.ntrig), 'accS', zeros(3,4), 'accW', zeros(3,4));
for c = 1:3
    ss = R(c).t >= P.Tss;
    for i = 1:4
        A.accS(c,i) = max(vecnorm(R(c).sige(ss,:,i), 2, 2));
        A.accW(c,i) = max(vecnorm(R(c).ome(ss,:,i), 2, 2));
    end
end
bdclose('all'); cd(old);

% ---------------- Project B ----------------
addpath(fullfile(root, 'revisions', 'v2'));
setup_v2;
c = default_config(4); c.scenario = 'pointing'; c.seed = 101;
r = run_case_v2(c, [], 'v2');
saved = jsondecode(fileread(fullfile(root, 'revisions', 'v2', 'results', ...
    'comparison_20261014_224749_328', 'raw', 'n4_pointing_v2_seed101.json')));
keys = {'detection_accuracy','isolation_accuracy','false_positive_rate','link_outage_s','recovery_success'};
Bm = struct();
for k = 1:numel(keys)
    Bm.(keys{k}) = [r.metrics.(keys{k}) saved.metrics.(keys{k})];
end
bdclose('all');

B = struct('A', A, 'B', Bm, 'when', char(datetime('now')));
save(fullfile(out, 'baselines.mat'), 'B', 'R');
fprintf('\nPROJECT A  triggers (rows = case 1..3, cols = SC1..SC4):\n'); disp(A.ntrig);
fprintf('PROJECT A  max |sigma_e| for t >= %g s, per case: %s\n', P.Tss, mat2str(max(A.accS,[],2).', 3));
fprintf('PROJECT B  rerun vs saved (n4 pointing v2 seed101):\n');
for k = 1:numel(keys), fprintf('  %-22s %.6g  vs  %.6g\n', keys{k}, Bm.(keys{k})); end
end
