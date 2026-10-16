function results = int_tests()
%INT_TESTS  Integration checks on the saved scenario runs (int_scenarios)
%   and the baseline validation (int_validate). Prints PASS/FAIL per check.
here = int_setup();
S = load(fullfile(here, 'results', 'scenarios.mat'));
V = load(fullfile(here, 'results', 'validation.mat')); V = V.V;
ids = S.runs(:,1); get = @(id) S.R{strcmp(ids, id)};
results = struct('name', {}, 'pass', {}, 'detail', {});
    function check(name, ok, detail)
        results(end+1) = struct('name', name, 'pass', logical(ok), 'detail', detail);
        fprintf('%-4s %-62s %s\n', ternary(ok, 'PASS', 'FAIL'), name, detail);
    end

s1 = get('S1_healthy'); s2 = get('S2_attdist'); s3 = get('S3_optfault'); b0 = get('B_only_healthy');
m = s1.config.m; dt = s1.config.dt;

% 1 dimensions and sample times
ok = size(s1.Y,2) == 26*m && size(s1.D,2) == 8*m+4 && size(s1.resid,2) == 2*m && size(s1.phi,2) == 2*m ...
     && max(abs(diff(s1.t) - dt)) < 1e-9 && abs(s1.A.t(2) - s1.A.t(1) - dt) < 1e-9;
check('Signal dimensions and sample times', ok, sprintf('Y %dx%d, D %dx%d, LOS %dx%d, B dt %.3f s', size(s1.Y), size(s1.D), size(s1.resid), dt));

% 2 units / frame: logged LOS equals 4*atan(|sigma_e|) projection of SC1 attitude error (rad)
k = find(s1.A.t >= 45, 1); se = squeeze(s1.A.sige(k,:,1)).';
phi = 4*atan(norm(se))*se/norm(se); err = max(abs(phi(2:3) - s1.phi(k,1:2).'));
check('LOS = MRP->rotation vector, body y/z axes, radians', err < 1e-9, sprintf('max abs diff %.2e rad at t = %.2f s', err, s1.A.t(k)));

% 3 both original controllers still run
check('Project A controller triggers on all 4 spacecraft (coupled run)', all(s3.A.ntrig > 0), sprintf('triggers %s', mat2str(s3.A.ntrig)));
acts = unique(s3.D(s3.t >= 41, 3)).';
check('Project B supervisor probes and corrects (S3)', all(ismember([2 3], acts)), sprintf('actions used %s', mat2str(acts)));

% 4 attitude disturbance reaches optical pointing through the interface
w = s1.t >= 41;
r1 = max(vecnorm(s1.resid(w,1:2),2,2)); r2 = max(vecnorm(s2.resid(w,1:2),2,2));
check('Attitude disturbance raises link-1 LOS residual', r2 > 2*r1, sprintf('max residual %.1f -> %.1f urad', 1e6*r1, 1e6*r2));
check('Attitude disturbance causes link-1 outage only when coupled', s2.metrics.link_outage_s > 0 && b0.metrics.link_outage_s == 0, ...
    sprintf('coupled %.2f s vs uncoupled %.2f s', s2.metrics.link_outage_s, b0.metrics.link_outage_s));

% 5 diagnosis gets no hidden truth
bad = {'scenario','faultStart','faultEnd','severity','profile','fault_input','truth'};
txt = [fileread(fullfile(here,'v2_decision_step_los.m')) fileread(fullfile(here,'int_attitude_to_los.m'))];
txt = regexprep(txt, '%[^\n]*', '');                   % ignore comments
found = bad(cellfun(@(b) contains(txt, b), bad));
check('No fault truth/schedule tokens in decision step or interface', isempty(found), sprintf('found: %s', strjoin(found, ',')));
check('Interface output independent of injected optical fault', isequal(s1.resid, s3.resid), 'S1 and S3 residual logs identical');

% 6 routing reported correctly: recompute route from logged availabilities
c = s2.config; g = 8*m; wr = s2.t >= 41 & s2.t < 50; mism = 0;
% The supervisor's decision log at sample k+1 holds the route computed from
% the measurements at sample k (S-function Outputs runs before Update).
for kk = find(wr).'
    if kk == numel(s2.t), continue; end
    av = s2.Y(kk, 18:26:end) > 0.5;
    rr = route_network(c, av, s2.Y(kk,16:26:end), s2.Y(kk,17:26:end));
    mism = mism + double(xor(rr.throughput > 0, s2.D(kk+1, g+1) > 0));
end
check('Network throughput matches route recomputed from link availability', mism == 0, sprintf('%d mismatching samples (log row k+1 vs measurements k)', mism));
outSC1 = all(s2.Y(wr, 18 + 26*(find(c.edges(:,1)==1).' - 1)) < 0.5, 2);
check('Network outage happens only while all SC1 links are down', s2.metrics.network_outage_s <= dt*sum(outSC1) + 1e-9, ...
    sprintf('network outage %.2f s, all-SC1-links-down %.2f s', s2.metrics.network_outage_s, dt*sum(outSC1)));

% 7 baselines reproducible with the interface off
check('Project A trigger counts reproduced (Cases 2, 3)', isequal(V.A(2:3,:), V.Aref(2:3,:)), sprintf('%s', mat2str(V.A(2:3,:))));
check('Project A steady-state accuracy reproduced (all cases)', max(abs(V.accA - V.accAref)) < 1e-9, mat2str(V.accA.', 3));
sb = V.B.sensor; f = fieldnames(sb); same = true;
for q = 1:numel(f), v = sb.(f{q}); if numel(v) < 2, v(2) = NaN; end, same = same && (isequaln(v(1), v(2)) || abs(v(1)-v(2)) < 1e-9); end   % saved JSON null -> NaN
check('Project B sensor-fault trial reproduced exactly', same, 'all six metrics equal to saved Simulink trial');
pb = V.B.pointing;
check('Project B pointing trial: detection, false alarms, recovery equal', ...
    abs(pb.detection_accuracy(1)-pb.detection_accuracy(2)) < 1e-9 && abs(pb.false_positive_rate(1)-pb.false_positive_rate(2)) < 1e-9 && pb.recovery_success(1) == pb.recovery_success(2), ...
    sprintf('isolation %.3f vs %.3f (solver ode4 1 ms vs ode3 20 ms)', pb.isolation_accuracy));

% 8 integrated diagnosis matches standalone B under coupling
bp = get('B_only_pointing');
check('Mode 3 keeps standalone V2 diagnosis under attitude coupling (S3)', ...
    abs(s3.metrics.isolation_accuracy - bp.metrics.isolation_accuracy) < 1e-9 && s3.metrics.recovery_success == 1, ...
    sprintf('isolation %.3f vs %.3f, recovery %d', s3.metrics.isolation_accuracy, bp.metrics.isolation_accuracy, s3.metrics.recovery_success));

save(fullfile(here, 'results', 'tests.mat'), 'results');
fprintf('\n%d of %d checks passed\n', sum([results.pass]), numel(results));
if ~all([results.pass]), error('int_tests:failed', 'Some integration checks failed'); end
end

function s = ternary(c, a, b)
if c, s = a; else, s = b; end
end
