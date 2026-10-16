function V = int_validate()
%INT_VALIDATE  With the interface switched off (mode 0), the integrated
%   model must reproduce each original project.
%   A: trigger counts and steady-state accuracy for Cases 1-3, 0-60 s,
%      versus the Project A Simulink baseline (results/baselines.mat).
%   B: V2 metrics for the pointing and sensor scenarios versus the saved
%      Project B Simulink trials (fault times shifted by +40 s here).
here = int_setup();
Bl = load(fullfile(here, 'results', 'baselines.mat'));
V.A = zeros(3, 4); V.Aref = Bl.B.A.ntrig; V.accA = zeros(3,1);
for c = 1:3
    r = int_run('scenario', 'normal', 'mode', 0, 'attCase', c, 'Tend', 60);
    V.A(c,:) = r.A.ntrig;
    ss = r.A.t >= 40;
    V.accA(c) = max(max(squeeze(vecnorm(r.A.sige(ss,:,:), 2, 2))));
end
V.accAref = max(Bl.B.A.accS, [], 2);
fprintf('\nProject A trigger counts, integrated (mode 0) vs baseline:\n');
disp([V.A V.Aref]);
fprintf('Project A max |sigma_e| t>=40 s, integrated vs baseline: %s vs %s\n', mat2str(V.accA.', 3), mat2str(V.accAref.', 3));

root = fileparts(here);
keys = {'detection_accuracy','isolation_accuracy','false_positive_rate','uncertain_frequency','link_outage_s','recovery_success'};
scen = {'pointing','sensor','power'};
V.B = struct();
for s = 1:numel(scen)
    r = int_run('scenario', scen{s}, 'mode', 0);
    saved = jsondecode(fileread(fullfile(root, 'revisions', 'v2', 'results', ...
        'comparison_20261014_224749_328', 'raw', sprintf('n4_%s_v2_seed101.json', scen{s}))));
    fprintf('\nProject B %s, integrated (mode 0) vs saved Simulink trial:\n', scen{s});
    for k = 1:numel(keys)
        a = r.metrics.(keys{k}); b = saved.metrics.(keys{k});
        V.B.(scen{s}).(keys{k}) = [a b];
        fprintf('  %-22s %8.4f  vs %8.4f\n', keys{k}, a, b);
    end
end
save(fullfile(here, 'results', 'validation.mat'), 'V');
end
