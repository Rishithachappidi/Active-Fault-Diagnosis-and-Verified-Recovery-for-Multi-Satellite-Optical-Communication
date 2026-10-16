function S = int_config(varargin)
%INT_CONFIG  Configuration of one integrated run.
%   S = int_config('scenario','pointing','attCase',3,'mode',2, ...)
%
%   Time line (one simulation, one clock):
%     0  - 40 s  Project A formation converges (paper: "within 40 s").
%                Project B terminals run uncoupled (warm-up).
%     40 s       Optical link acquisition: attitude coupling switched on.
%     41 - 50 s  Scoring window of Project B (450 samples at 20 ms).
%     42 - 48 s  Optical fault window (Project B fault_input, unchanged).
o = struct('scenario','normal','profile','sudden','seed',101,'attCase',3, ...
           'mode',2,'tauCPA',0.005,'dist',[],'tAcq',40,'Tend',50);
for k = 1:2:numel(varargin), o.(varargin{k}) = varargin{k+1}; end

% ---- Project A (unchanged parameters) ----
P = sff_params();
S.P = P; S.Ts = P.Ts; S.umax = P.umax; S.x0 = sff_x0(P); S.CASE = o.attCase;
S.Tend = o.Tend;

% ---- Project B (unchanged model, shifted schedule) ----
c = default_config(4);
c.scenario = o.scenario; c.profile = o.profile; c.seed = o.seed;
c.T = o.Tend; c.warmup = o.tAcq + 1;
c.faultStart = o.tAcq + 2; c.faultEnd = o.tAcq + 8;
S.cfg = prepare_config(c);
S.tx  = S.cfg.edges(:,1);                 % transmitting spacecraft of each link

% ---- interface ----
S.MODE = o.mode; S.TAUCPA = o.tauCPA; S.TACQ = o.tAcq;
[~,~,phi0] = int_attitude_to_los(0, S.x0, zeros(2*S.cfg.m,1), 1, o.tauCPA, 0, S.tx);
S.c0 = phi0;                              % CPA starts locked on the initial attitude

% ---- optional external disturbance torque on the spacecraft (N*m) ----
% o.dist = struct('sc',1,'t0',43,'dur',0.5,'tau',[0;0.02;-0.02])
D = zeros(4,13);                          % [time, 12 torque components]
D(:,1) = [0; 1; 2; S.Tend+1];
if ~isempty(o.dist)
    d = o.dist;
    D(:,1) = [0; d.t0; d.t0 + d.dur; S.Tend+1];
    D(2, 1 + 3*(d.sc-1) + (1:3)) = d.tau(:).';
end
S.distData = D;
S.opts = o;
end
