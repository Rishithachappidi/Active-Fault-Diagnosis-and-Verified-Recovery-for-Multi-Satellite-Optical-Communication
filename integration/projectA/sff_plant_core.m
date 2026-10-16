function dx = sff_plant_core(t, x, usat)
%SFF_PLANT_CORE  Continuous-time dynamics of the 4-spacecraft formation.
%   Implements eq. (1)-(2) of Xie/Sheng/Chen (IEEE TAES 2024) for all four
%   spacecraft.  This is the body of the "SpacecraftDynamics" MATLAB
%   Function block in sff_ets_model.slx.
%
%   x    : 24x1  = [sigma_1; omega_1; sigma_2; omega_2; ...; sigma_4; omega_4]
%   usat : 12x1  = sat(u) already clipped by the Saturation block (|u|<=umax)
%   dx   : 24x1  state derivative
%
%       sigmadot_i = G(sigma_i) * omega_i                              (1)
%       J_i omegadot_i = -omega_i^x J_i omega_i
%                        + Gamma_i sat(u_i) + ubar_i + rho_i           (2)
%#codegen

% inertia matrices J_1..J_4 (diagonals), Section IV
Jd = [5.1 4.8 5.0
      4.9 4.9 5.1
      5.0 5.2 5.1
      4.8 5.1 4.9];

% actuator effectiveness matrices Gamma_1..Gamma_4 (diagonals)
Gd = [0.8 0.7 0.8
      0.6 0.8 0.7
      0.5 0.8 0.6
      0.7 0.6 0.7];

% ---- lumped disturbances rho_i(t)  [N*m], Section IV -----------------
rho = zeros(3,4);
rho(:,1) = [2 + sin(0.1*t); 1 + 2*cos(0.2*t); 2 + sin(0.1*t)]*1e-3;
rho(:,2) = [1 + 2*cos(0.2*t); 2 + sin(0.1*t); 1 + 2*cos(0.2*t)]*1e-3;
rho(:,3) = [3 + 3*cos(0.1*t); 2 + cos(0.1*t); 2 + sin(0.2*t)]*1e-3;
rho(:,4) = [2 + sin(0.2*t); 1 + 2*sin(0.2*t); 3 + 3*cos(0.1*t)]*1e-3;

% ---- drift torques ubar_i(t)  [N*m], Section IV ----------------------
ub = zeros(3,4);
ub(:,1) = [ 0.2 + 0.3*cos(0.2*t); -0.3 + 0.1*cos(0.1*t);  0.1 - 0.2*sin(0.2*t)]*1e-3;
ub(:,2) = [-0.3 + 0.1*sin(0.1*t); -0.2 + 0.3*cos(0.2*t);  0.3 - 0.3*sin(0.1*t)]*1e-3;
ub(:,3) = [-0.2 + 0.2*sin(0.1*t); -0.2 + 0.2*cos(0.3*t);  0.2 - 0.1*cos(0.3*t)]*1e-3;
ub(:,4) = [ 0.1 + 0.3*cos(0.2*t); -0.3 + 0.1*sin(0.2*t);  0.1 - 0.2*sin(0.2*t)]*1e-3;

dx = zeros(24,1);
for i = 1:4
    ks  = 6*(i-1);
    sig = x(ks+1:ks+3);
    om  = x(ks+4:ks+6);

    J = diag(Jd(i,:).');
    G = 0.25*(1 - (sig.'*sig))*eye(3) + 0.5*sff_skew(sig) + 0.5*(sig*sig.');

    u  = usat(3*(i-1)+1 : 3*(i-1)+3);
    tq = diag(Gd(i,:).')*u + ub(:,i) + rho(:,i);

    dx(ks+1:ks+3) = G*om;
    dx(ks+4:ks+6) = J \ ( -sff_skew(om)*J*om + tq );
end
end

% ---------------------------------------------------------------------
function S = sff_skew(v)
%#codegen
S = [    0  -v(3)   v(2)
      v(3)     0   -v(1)
     -v(2)   v(1)     0 ];
end
