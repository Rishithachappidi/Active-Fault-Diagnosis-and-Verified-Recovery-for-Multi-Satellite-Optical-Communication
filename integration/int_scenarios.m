function T = int_scenarios()
%INT_SCENARIOS  The four integration scenarios plus the comparisons used in
%   the results table. Writes results/scenarios.csv, results/scenarios.mat
%   and figures in results/figures.
here = int_setup();
outDir = fullfile(here, 'results'); figDir = fullfile(outDir, 'figures');
if ~isfolder(figDir), mkdir(figDir); end

dist = struct('sc', 1, 't0', 43, 'dur', 0.5, 'tau', [0; 0.05; -0.05]);   % N*m on SC1 (link 1 transmitter)
runs = {
 % id                    label                                              args
 'S1_healthy',          'S1 Healthy spacecraft, healthy link',              {'scenario','normal','mode',3}
 'S2_attdist',          'S2 Attitude disturbance, healthy link',            {'scenario','normal','mode',3,'dist',dist}
 'S3_optfault',         'S3 Optical pointing fault',                        {'scenario','pointing','mode',3}
 'S4_combined',         'S4 Attitude disturbance + optical pointing fault', {'scenario','pointing','mode',3,'dist',dist}
 'B_only_pointing',     'Project B alone (coupling off), pointing fault',   {'scenario','pointing','mode',0}
 'B_only_healthy',      'Project B alone (coupling off), healthy',          {'scenario','normal','mode',0}
 'naive_pointing',      'Naive coupling (supervisor unaware), pointing',    {'scenario','pointing','mode',2}
 'naive_attdist',       'Naive coupling, attitude disturbance',             {'scenario','normal','mode',2,'dist',dist}
 'raw_healthy',         'No coarse pointing (raw attitude), healthy',       {'scenario','normal','mode',1}
 'S1_case1',            'S1 with attitude Case 1 (time-driven)',            {'scenario','normal','mode',3,'attCase',1}
 'S1_case2',            'S1 with attitude Case 2 (event-triggered)',        {'scenario','normal','mode',3,'attCase',2}
 'S3_case2',            'S3 with attitude Case 2 (event-triggered)',        {'scenario','pointing','mode',3,'attCase',2}
};
n = size(runs, 1);
R = cell(n, 1);
rows = struct([]);
for k = 1:n
    fprintf('Running %s ...\n', runs{k,1});
    r = int_run(runs{k,3}{:});
    R{k} = r;
    m = r.metrics; x = r.extra; w = r.t >= 41 & r.t < 50;
    row = struct('id', string(runs{k,1}), 'label', string(runs{k,2}), ...
        'attCase', r.opts.attCase, 'mode', r.opts.mode, ...
        'att_max_sigma_err_SC1', r.A.maxSigmaErr(1), 'att_triggers_SC1', r.A.ntrig(1), ...
        'att_triggers_total', sum(r.A.ntrig), ...
        'los_rms_urad', r.losRMS_urad, 'cpa_residual_rms_urad', r.residRMS_urad, ...
        'cpa_residual_max_urad', 1e6*max(vecnorm(r.resid(w,1:2), 2, 2)), ...
        'detection_accuracy', m.detection_accuracy, 'isolation_accuracy', m.isolation_accuracy, ...
        'false_positive_rate', m.false_positive_rate, 'uncertain_frequency', m.uncertain_frequency, ...
        'link1_outage_s', m.link_outage_s, 'network_outage_s', m.network_outage_s, ...
        'link_availability', m.link_availability, 'recovery_success', m.recovery_success, ...
        'postclear_outage_s', x.postclear_outage_s, 'reroute_samples', sum(r.D(w, 8*r.config.m + 4) > 1), ...
        'labels_used', string(mat2str(unique(r.D(w,1)).')), 'runtime_s', r.runtime);
    if isempty(rows), rows = row; else, rows(end+1) = row; end %#ok<AGROW>
end
T = struct2table(rows);
writetable(T, fullfile(outDir, 'scenarios.csv'));
save(fullfile(outDir, 'scenarios.mat'), 'T', 'R', 'runs', '-v7.3');
disp(T(:, {'id','cpa_residual_rms_urad','detection_accuracy','isolation_accuracy','false_positive_rate','link1_outage_s','network_outage_s','recovery_success','labels_used'}));

% ---------------- figures ----------------
for k = 1:4, scenarioFigure(R{k}, runs{k,2}, fullfile(figDir, sprintf('%s.png', runs{k,1}))); end
compareFigure(R, runs, fullfile(figDir, 'coupling_comparison.png'));
end

function scenarioFigure(r, ttl, file)
f = figure('Visible', 'off', 'Position', [100 100 1100 900]);
tl = tiledlayout(f, 4, 1, 'TileSpacing', 'compact'); title(tl, ttl);
tA = r.A.t; t = r.t; w = t >= 39;
nexttile; plot(tA(tA>=39), 1e6*4*vecnorm(r.A.sige(tA>=39,:,1), 2, 2), 'LineWidth', 1); grid on;
ylabel({'SC1 attitude', 'error (\murad)'}); xlim([39 50]); xline(40, ':', 'link acquisition');
nexttile; plot(t(w), 1e6*r.resid(w,1), t(w), 1e6*r.resid(w,2), 'LineWidth', 1); grid on;
ylabel({'Residual LOS error', 'after CPA (\murad)'}); legend('y', 'z', 'Location', 'best'); xlim([39 50]);
nexttile; plot(t(w), 1e6*r.Y(w,16), 'LineWidth', 1.2); hold on; yline(1.5, '--', '1.5 \muW');
grid on; ylabel({'Link 1 received', 'power (\muW)'}); xlim([39 50]);
nexttile; stairs(t(w), r.D(w,4), '--', 'LineWidth', 1); hold on; stairs(t(w), r.D(w,1), 'LineWidth', 1.2);
grid on; ylabel('Class'); xlabel('Time (s)'); legend('true fault', 'V2 diagnosis', 'Location', 'best'); xlim([39 50]); ylim([-0.5 8.5]);
exportgraphics(f, file, 'Resolution', 140); close(f);
end

function compareFigure(R, runs, file)
ids = runs(:,1); get = @(id) R{strcmp(ids, id)};
f = figure('Visible', 'off', 'Position', [100 100 1100 420]);
tl = tiledlayout(f, 1, 2, 'TileSpacing', 'compact');
title(tl, 'Pointing fault on link 1: received power');
pairs = {'B_only_pointing','Project B alone'; 'naive_pointing','Naive coupling'; 'S3_optfault','Integrated (mode 3)'};
nexttile; hold on;
for q = 1:3, r = get(pairs{q,1}); w = r.t >= 39; plot(r.t(w), 1e6*r.Y(w,16), 'LineWidth', 1.1); end
yline(1.5, '--'); grid on; xlim([39 50]); ylabel('\muW'); xlabel('Time (s)'); legend(pairs(:,2), 'Location', 'southwest');
nexttile; hold on;
for q = 1:3, r = get(pairs{q,1}); w = r.t >= 39; stairs(r.t(w), r.D(w,1) + 0.08*(q-2), 'LineWidth', 1.1); end
r = get('S3_optfault'); w = r.t >= 39; stairs(r.t(w), r.D(w,4), 'k--');
grid on; xlim([39 50]); ylim([-0.5 8.5]); ylabel('Class (1 = pointing, 7 = uncertain, 8 = combined)'); xlabel('Time (s)');
legend([pairs(:,2); {'true fault'}], 'Location', 'northeast');
exportgraphics(f, file, 'Resolution', 140); close(f);
end
