function [coupling, cdot, phiTx, resid, losTelemetry] = int_attitude_to_los(t, x, c, mode, tauCPA, tAcq, tx)
%INT_ATTITUDE_TO_LOS  The single interface between Project A and Project B.
%
%   Spacecraft attitude error -> optical line-of-sight (LOS) error of the
%   terminal on each optical link.
%
%   x      : 24x1 Project A state [sigma_1; omega_1; ...; sigma_4; omega_4]
%   c      : 2m x1 coarse-pointing (CPA) compensation state [rad]
%   mode   : 0 = uncoupled (baselines)
%            1 = raw coupling, no coarse pointing
%            2 = CPA compensation; the fine terminal and supervisor are NOT told
%                about the residual (it acts as an unknown optical offset)
%            3 = CPA compensation + the measurable CPA residual d is given to
%                the Project B supervisor as telemetry, used only in its optical
%                power model (supervisor_v2_los). Fine-stage commands unchanged.
%   tAcq   : link acquisition time; coupling active for t >= tAcq
%   tx     : m x1 transmitting spacecraft of each link
%
%   Equations (small angles, transmitting spacecraft i):
%     sigma_e  = sigma_i - sigma_d(t)                                   (Project A error)
%     phi      = 4*atan(|sigma_e|) * sigma_e/|sigma_e|                  (MRP -> rotation vector)
%     phi_LOS  = [phi_y; phi_z]                                         (boresight along body +x)
%     CPA:       c_dot = (phi_LOS - c)/tauCPA,   d = phi_LOS - c
%     Plant:     optical error = theta_terminal + offset_fault + d       -> u(9:10) += d
%     Mode 3:    losTelemetry = d  (supervisor predicts P = P0*g*exp(-2|q+d+delta|^2/alpha^2))
%   No fault label, fault schedule or fault parameter is used here.
%#codegen
m = numel(tx);
coupling = zeros(11*m, 1);
losTelemetry = zeros(2*m, 1);
cdot  = zeros(2*m, 1);
phiTx = zeros(2*m, 1);
resid = zeros(2*m, 1);

sd = [ 3 + 2*sin(0.1*t)
       5 + 3*cos(0.2*t)
      -2 +   cos(0.1*t)] * 1e-3;                   % Project A reference sigma_d(t)

for j = 1:m
    i  = tx(j);
    se = x(6*(i-1)+1 : 6*(i-1)+3) - sd;
    ns = norm(se);
    if ns > 0
        phi = 4*atan(ns) * se / ns;
    else
        phi = zeros(3,1);
    end
    p  = phi(2:3);
    k  = 2*j-1:2*j;
    phiTx(k) = p;
    cdot(k)  = (p - c(k)) / tauCPA;
    if mode == 1
        d = p;
    elseif mode >= 2
        d = p - c(k);
    else
        d = zeros(2,1);
    end
    if t < tAcq
        d = zeros(2,1);
    end
    resid(k) = d;
    coupling(11*(j-1)+9 : 11*(j-1)+10) = d;              % physics: LOS disturbance
    if mode == 3
        losTelemetry(k) = d;                              % known to the spacecraft
    end
end
end
