function R = sff_run_all(rebuild)
%SFF_RUN_ALL  Build the Simulink model, run the three simulation cases of
%   X. Xie, T. Sheng, X. Chen, "Dynamic Event-Triggered and Self-Triggered
%   Fault-Tolerant Attitude Control for Multiple Spacecraft Systems With
%   Uncertainties and Input Saturation," IEEE TAES 60(3):2922-2933, 2024,
%   and reproduce Figs. 2-15 and Tables I-III.
%
%   Usage:   R = sff_run_all;        % build (if needed) + run everything
%            R = sff_run_all(true);  % force a rebuild of the .slx
%
%   Case 1: time-driven controller (31), 10 Hz
%   Case 2: dynamic event-triggered controller (8) + (10) + (11)
%   Case 3: self-triggered controller (8) + (26)

if nargin < 1, rebuild = false; end
P   = sff_params();
mdl = P.modelName;

% ---------------------------------------------------------------------
% 1. Build / load the block diagram
% ---------------------------------------------------------------------
if rebuild || ~exist([mdl '.slx'], 'file')
    fprintf('Building Simulink model %s.slx ...\n', mdl);
    sff_build_model(P);
else
    if ~bdIsLoaded(mdl), load_system(mdl); end
end

% sanity check: gains must match the values printed in the paper
assert(max(abs(P.k1 - [12.5 12.5 12.5 25])) < 1e-12, 'k1 mismatch');
assert(max(abs(P.k2 - [11/6 11/6 11/6 11/3])) < 1e-12, 'k2 mismatch');

mws = get_param(mdl, 'ModelWorkspace');
assignin(mws, 'Ts',   P.Ts);
assignin(mws, 'Tend', P.Tend);
assignin(mws, 'umax', P.umax);
assignin(mws, 'x0',   sff_x0(P));

% ---------------------------------------------------------------------
% 2. Run the three cases
% ---------------------------------------------------------------------
R = struct('t',{},'sig',{},'om',{},'ucmd',{},'usat',{},'trig',{}, ...
           'chi',{},'s',{},'sige',{},'ome',{},'ntrig',{});
for c = 1:3
    fprintf('Running Case %d ...\n', c);
    assignin(mws, 'CASE', c);
    out = sim(mdl);

    t    = out.get('t_log');    t = t(:);
    N    = numel(t);
    % To Workspace "Array" logs are N-by-width; force that orientation
    ori  = @(v) sffOrient(v, N);
    x    = ori(out.get('x_log'));
    ucmd = ori(out.get('ucmd_log'));
    usat = ori(out.get('usat_log'));
    trg  = ori(out.get('trig_log'));
    chi  = ori(out.get('chi_log'));
    s    = ori(out.get('s_log'));

    [sd, od] = sff_ref(t);                       % 3xN

    sig  = zeros(numel(t),3,4);  om   = zeros(numel(t),3,4);
    sige = zeros(numel(t),3,4);  ome  = zeros(numel(t),3,4);
    for i = 1:4
        sig(:,:,i)  = x(:, 6*(i-1)+1 : 6*(i-1)+3);
        om(:,:,i)   = x(:, 6*(i-1)+4 : 6*(i-1)+6);
        sige(:,:,i) = sig(:,:,i) - sd.';         % sigma_ei = sigma_i - sigma_d
        ome(:,:,i)  = om(:,:,i)  - od.';         % omega_ei = omega_i - omega_d
    end

    inWin = t < P.Tend - P.Ts/2;                 % trigger window 0-60 s
    R(c).t = t; R(c).sig = sig; R(c).om = om;
    R(c).ucmd = ucmd; R(c).usat = usat; R(c).trig = trg;
    R(c).chi = chi;   R(c).s = s;
    R(c).sige = sige; R(c).ome = ome;
    R(c).ntrig = sum(trg(inWin,:) > 0.5, 1);     % per spacecraft
end

% ---------------------------------------------------------------------
% 3. Figures 2-15 (same order and content as the paper)
% ---------------------------------------------------------------------
figBase = [2 6 11];                              % first figure number per case
for c = 1:3
    f = figBase(c);
    plotStack(R(c).t, R(c).sige, f  , sprintf('Fig. %d. Attitude errors in Case %d', f  , c), '\sigma_{e}');
    plotStack(R(c).t, R(c).ome , f+1, sprintf('Fig. %d. Angular velocity errors in Case %d', f+1, c), '\omega_{e} (rad/s)');
    plotCtrl (R(c).t, R(c).ucmd, f+2, sprintf('Fig. %d. Control inputs in Case %d', f+2, c), []);
    plotCtrl (R(c).t, R(c).usat, f+3, sprintf('Fig. %d. Control inputs with amplitude constraints in Case %d', f+3, c), P.umax);
end
plotTrig(R(2).t, R(2).trig, 10, 'Fig. 10. Triggering instants in Case 2');
plotTrig(R(3).t, R(3).trig, 15, 'Fig. 15. Triggering instants in Case 3');

% Save every figure into the repository-level output_images folder.
% This keeps all generated output images in one GitHub-friendly location.
simDir  = fileparts(mfilename('fullpath'));
repoDir = fileparts(simDir);
figDir  = fullfile(repoDir, 'output_images');
if ~exist(figDir,'dir'), mkdir(figDir); end
for f = 2:15
    if ishandle(f)
        exportgraphics(figure(f), fullfile(figDir, sprintf('Fig%02d.png', f)), ...
                       'Resolution', 150);
    end
end
fprintf('\nFigures 2-15 written to %s\n', figDir);

% ---------------------------------------------------------------------
% 4. Tables I-III
% ---------------------------------------------------------------------
ss = R(1).t >= P.Tss;                            % steady state: t >= 40 s
accS = zeros(3,4); accW = zeros(3,4);
for c = 1:3
    for i = 1:4
        accS(c,i) = max(max(abs(R(c).sige(ss,:,i))));
        accW(c,i) = max(max(abs(R(c).ome (ss,:,i))));
    end
end

fprintf('\n================ TABLE I  Convergence Accuracy (t >= %g s) ================\n', P.Tss);
fprintf('%-8s %-12s %-12s %-12s %-12s\n','Case','SC1','SC2','SC3','SC4');
for c = 1:3
    fprintf('Case %d  |sigma_e|  %-11.3e %-11.3e %-11.3e %-11.3e\n', c, accS(c,:));
    fprintf('        |omega_e|  %-11.3e %-11.3e %-11.3e %-11.3e\n',    accW(c,:));
end
fprintf('Overall bound   |sigma_e| : %.3e (C1)  %.3e (C2)  %.3e (C3)\n', max(accS,[],2));
fprintf('Overall bound   |omega_e| : %.3e (C1)  %.3e (C2)  %.3e (C3)\n', max(accW,[],2));

fprintf('\n================ TABLE II  Trigger Times (0-60 s) ========================\n');
fprintf('%-8s %-8s %-8s %-8s %-8s %-8s\n','Case','SC1','SC2','SC3','SC4','Total');
for c = 1:3
    fprintf('Case %-3d %-8d %-8d %-8d %-8d %-8d\n', c, R(c).ntrig, sum(R(c).ntrig));
end

n1 = sum(R(1).ntrig);
fprintf('\n================ TABLE III  Performance Comparison =======================\n');
fprintf('%-28s %-14s %-14s %-14s\n','', 'Case 1','Case 2','Case 3');
fprintf('%-28s %-14d %-14d %-14d\n','Total triggers (0-60 s)', ...
        n1, sum(R(2).ntrig), sum(R(3).ntrig));
fprintf('%-28s %-14s %-14.1f %-14.1f\n','Change vs Case 1 [%]','--', ...
        100*(sum(R(2).ntrig)-n1)/n1, 100*(sum(R(3).ntrig)-n1)/n1);
fprintf('%-28s %-14s %-14s %-14.1f\n','Change vs Case 2 [%]','--','--', ...
        100*(sum(R(3).ntrig)-sum(R(2).ntrig))/sum(R(2).ntrig));
fprintf('%-28s %-14.2e %-14.2e %-14.2e\n','Attitude accuracy', max(accS,[],2));
fprintf('%-28s %-14.2e %-14.2e %-14.2e\n','Ang. velocity accuracy', max(accW,[],2));
fprintf('%-28s %-14s %-14s %-14s\n','Continuous communication','yes','no','no');
fprintf('%-28s %-14s %-14s %-14s\n','Continuous computation','yes','yes','no');
fprintf('=========================================================================\n');
end

% =====================================================================
function v = sffOrient(v, N)
%SFFORIENT  Return the log as N-by-width regardless of how it was stored.
if ndims(v) == 3          % column-vector signal logged as [width 1 N]
    v = permute(v, [3 1 2]);
end
if size(v,1) ~= N && size(v,2) == N
    v = v.';
end
end

% =====================================================================
function plotStack(t, e, fignum, ttl, ylab)
figure(fignum); clf;
try, set(gcf,'Theme','light'); catch, end
set(gcf,'Color','w');
lbl = {'x','y','z'};
for k = 1:3
    subplot(3,1,k); hold on; grid on;
    for i = 1:4
        plot(t, e(:,k,i), 'LineWidth', 1.1);
    end
    ylabel(sprintf('%s_{%s}', ylab, lbl{k}));
    if k == 1, title(ttl, 'FontWeight','normal'); end
    if k == 3, xlabel('Time (s)'); end
    if k == 1, legend({'SC1','SC2','SC3','SC4'}, 'Orientation','horizontal', ...
                      'Location','northeast'); end
end
end

function plotCtrl(t, u, fignum, ttl, lim)
figure(fignum); clf;
try, set(gcf,'Theme','light'); catch, end
set(gcf,'Color','w');
for i = 1:4
    subplot(4,1,i); hold on; grid on;
    plot(t, u(:,3*(i-1)+1:3*(i-1)+3), 'LineWidth', 1.0);
    if ~isempty(lim)
        yline( lim, 'k--'); yline(-lim, 'k--');
        ylim([-1.25*lim 1.25*lim]);
    end
    ylabel(sprintf('u_%d (N\\cdotm)', i));
    if i == 1
        title(ttl, 'FontWeight','normal');
        legend({'x','y','z'}, 'Orientation','horizontal','Location','northeast');
    end
    if i == 4, xlabel('Time (s)'); end
end
end

function plotTrig(t, trg, fignum, ttl)
figure(fignum); clf;
try, set(gcf,'Theme','light'); catch, end
set(gcf,'Color','w');
for i = 1:4
    subplot(4,1,i); grid on;
    idx = trg(:,i) > 0.5;
    ti  = t(idx);
    if isempty(ti)
        dt = [];
    else
        dt = [ti(1); diff(ti)];              % interevent time
    end
    stem(ti, dt, 'filled', 'MarkerSize', 2);
    ylabel(sprintf('SC%d', i));
    if i == 1, title(ttl, 'FontWeight','normal'); end
    if i == 4, xlabel('Time (s)'); end
end
end
