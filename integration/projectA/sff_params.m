function P = sff_params()
%SFF_PARAMS  All simulation parameters from Section IV of
%   X. Xie, T. Sheng, X. Chen, "Dynamic Event-Triggered and Self-Triggered
%   Fault-Tolerant Attitude Control for Multiple Spacecraft Systems With
%   Uncertainties and Input Saturation", IEEE Trans. Aerosp. Electron.
%   Syst., vol. 60, no. 3, pp. 2922-2933, June 2024.
%
%   Every number below is taken verbatim from the paper (Section IV,
%   pp. 2927-2928).  These same values are hard-coded inside the generated
%   MATLAB Function block sources (sff_controller_core.m, sff_plant_core.m)
%   so that Simulink code generation sees compile-time constants; the
%   function SFF_CHECK_CONSISTENCY verifies the two copies agree.

% ---- communication topology (Fig. 1) --------------------------------
P.n = 4;
P.A = [0 1 0 0
       1 0 1 0
       1 1 0 0
       1 0 0 0];
P.B = diag([1 0 0 0]);

% ---- control parameters ---------------------------------------------
P.r      = 0.6;        % sliding-surface slope,           r  > 0
P.k0     = 0.1;        % k0 > 0  (Theorem 1)
P.alpha  = 0.001*ones(1,4);   % alpha_i  (Assumption 2)
P.delta  = 0.3  *ones(1,4);   % delta_i  (Assumption 3)
P.eps    = 1e-4 *ones(1,4);   % epsilon_i (eq. 10)
P.chi0   = 0.3  *ones(1,4);   % chi_i(0) > 0
P.beta1  = 5    *ones(1,4);   % beta_1i  (eq. 11)
P.beta2  = 10   *ones(1,4);   % beta_2i  (eq. 11)
P.gamma  = 0.5  *ones(1,4);   % 0 < gamma_i < 1

% gains from Theorem 1:
%   k1i = 2(gamma_i*beta1i + beta2i) / (sum_j a_ij + b_i)
%   k2i = (k0 + 1) / [ (sum_j a_ij + b_i) * delta_i ]
P.d  = sum(P.A,2).' + diag(P.B).';        % = [2 2 2 1]
P.k1 = 2*(P.gamma.*P.beta1 + P.beta2) ./ P.d;
P.k2 = (P.k0 + 1) ./ (P.d .* P.delta);

% ---- actuation -------------------------------------------------------
P.umax = 0.2;                  % N*m, saturation limit

% inertia matrices  [kg*m^2]
P.J = zeros(3,3,4);
P.J(:,:,1) = diag([5.1 4.8 5.0]);
P.J(:,:,2) = diag([4.9 4.9 5.1]);
P.J(:,:,3) = diag([5.0 5.2 5.1]);
P.J(:,:,4) = diag([4.8 5.1 4.9]);

% actuator effectiveness matrices Gamma_i
P.Gam = zeros(3,3,4);
P.Gam(:,:,1) = diag([0.8 0.7 0.8]);
P.Gam(:,:,2) = diag([0.6 0.8 0.7]);
P.Gam(:,:,3) = diag([0.5 0.8 0.6]);
P.Gam(:,:,4) = diag([0.7 0.6 0.7]);

% ---- initial conditions ---------------------------------------------
P.sigma0 = [ 0.15  0.22 -0.15
             0.08  0.18 -0.13
            -0.09  0.12  0.18
             0.12 -0.13  0.15].';        % 3x4, column i = sigma_i(0)

P.omega0 = [ 0.15 -0.08  0.12
            -0.14  0.11  0.13
             0.16  0.12 -0.07
            -0.13 -0.17  0.12].';        % 3x4, column i = omega_i(0)

% ---- simulation setup -------------------------------------------------
P.Ts    = 1e-3;    % integration / trigger-detection step  (1 kHz)
P.Tend  = 60;      % s, matches Tables I-III window 0-60 s
P.Tcase1 = 0.1;    % Case 1 time-driven period -> 10 Hz -> 600 updates
P.Tss   = 40;      % s, steady state assumed after 40 s (paper: "within 40 s")

P.modelName = 'sff_ets_model';
end
