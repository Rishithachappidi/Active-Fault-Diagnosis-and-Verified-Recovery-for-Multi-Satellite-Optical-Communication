function [u, trig, chi_out, s_out] = sff_controller_core(t, x, mode)
%SFF_CONTROLLER_CORE  Distributed fault-tolerant attitude controller with
%   the three triggering mechanisms of Xie/Sheng/Chen (IEEE TAES 2024).
%
%   mode : 1 = Case 1, time-driven controller (31)
%          2 = Case 2, dynamic event-triggered controller (8)+(10)+(11)
%          3 = Case 3, self-triggered controller (8)+(26)
%
%   x = [sigma_1; omega_1; ... ; sigma_4; omega_4]

%#codegen

% ===================== Paper parameters ================================

A = [0 1 0 0
     1 0 1 0
     1 1 0 0
     1 0 0 0];

b = [1 0 0 0];

d = sum(A,2).' + b;

r     = 0.6;
k0    = 0.1;
alpha = 0.001 * ones(1,4);
delta = 0.3   * ones(1,4);
epsi  = 1e-4  * ones(1,4);
chi0  = 0.3   * ones(1,4);
beta1 = 5     * ones(1,4);
beta2 = 10    * ones(1,4);
gam   = 0.5   * ones(1,4);

% Theorem 1
k1 = 2*(gam.*beta1 + beta2) ./ d;
k2 = (k0 + 1) ./ (d .* delta);

% Inertia matrices
Jd = [5.1 4.8 5.0
      4.9 4.9 5.1
      5.0 5.2 5.1
      4.8 5.1 4.9];

% ||J_i^{-1}||_2 for diagonal inertia matrices
nJinv = 1 ./ min(Jd,[],2).';

n  = 4;
Ts = 1e-3;

% Case 1: 10 Hz
Tc1 = 0.1;


% ===================== Persistent trigger memory =======================

persistent isInit uHold sBcast oBcast skHold chi tNext

if isempty(isInit)

    isInit = true;

    % Initial commanded control
    uHold = zeros(12,1);

    % Initial broadcast states
    sBcast = zeros(12,1);
    oBcast = zeros(12,1);

    for j = 1:4

        kj = 6*(j-1);

        % Initial attitude
        sBcast(3*(j-1)+1 : 3*(j-1)+3) = ...
            x(kj+1 : kj+3);

        % Initial angular velocity
        oBcast(3*(j-1)+1 : 3*(j-1)+3) = ...
            x(kj+4 : kj+6);

    end

    % Sliding-variable memory
    skHold = zeros(12,1);

    % chi_i(0)
    chi = chi0(:);

    % Next scheduled trigger
    tNext = zeros(4,1);

end


% ===================== Reference trajectory =============================

[sd, od] = sff_ref_local(t);


% ===================== Snapshot of broadcast states =====================

sB = sBcast;
oB = oBcast;


% ===================== Outputs ==========================================

u     = uHold;
trig  = zeros(4,1);
s_out = zeros(12,1);


% ===================== Four spacecraft ================================

for i = 1:4

    ki = 3*(i-1);

    % Current spacecraft state
    sig = x(6*(i-1)+1 : 6*(i-1)+3);
    om  = x(6*(i-1)+4 : 6*(i-1)+6);


    % =================================================================
    % Formation errors
    % =================================================================

    e1 = b(i)*(sig - sd);
    e2 = b(i)*(om  - od);

    for j = 1:4

        if A(i,j) ~= 0

            e1 = e1 + ...
                (sig - sB(3*(j-1)+1 : 3*(j-1)+3));

            e2 = e2 + ...
                (om - oB(3*(j-1)+1 : 3*(j-1)+3));

        end

    end


    % =================================================================
    % Sliding variable
    % =================================================================

    s = e2 + r*e1;

    s_out(ki+1 : ki+3) = s;


    % =================================================================
    % CASE 1
    % Time-driven controller
    % =================================================================

    if mode == 1

        if t >= tNext(i) - Ts/2

            e1t = b(i)*(sig - sd);
            e2t = b(i)*(om  - od);

            for j = 1:4

                if A(i,j) ~= 0

                    e1t = e1t + ...
                        (sig - x(6*(j-1)+1 : 6*(j-1)+3));

                    e2t = e2t + ...
                        (om - x(6*(j-1)+4 : 6*(j-1)+6));

                end

            end

            st = e2t + r*e1t;

            Phi = 1 + norm(om) + norm(om)^2;

            u(ki+1 : ki+3) = ...
                -k1(i)*st ...
                -k2(i)*alpha(i)*Phi*sign(st);

            trig(i) = 1;

            tNext(i) = tNext(i) + Tc1;

        end


    % =================================================================
    % CASES 2 AND 3
    % =================================================================

    else

        % Equation (9)
        stil = ...
            skHold(ki+1 : ki+3) - s;

        nsk2 = ...
            skHold(ki+1 : ki+3).' * ...
            skHold(ki+1 : ki+3);

        fire = false;


        % =============================================================
        % CASE 2
        % Dynamic event-triggered controller
        % =============================================================

        if mode == 2

            if t <= 0

                fire = true;

            elseif (stil.'*stil - delta(i)*nsk2) ...
                    >= (chi(i) + epsi(i))

                fire = true;

            end


        % =============================================================
        % CASE 3
        % Self-triggered controller
        % =============================================================

        else

            if t >= tNext(i) - Ts/2

                fire = true;

            end

        end


        % =============================================================
        % Trigger event
        % =============================================================

        if fire

            % Broadcast current state
            sBcast(ki+1 : ki+3) = sig;
            oBcast(ki+1 : ki+3) = om;

            % Store current sliding variable
            skHold(ki+1 : ki+3) = s;

            % Equation (8)
            Phi = 1 + norm(om) + norm(om)^2;

            u(ki+1 : ki+3) = ...
                -k1(i)*s ...
                -k2(i)*alpha(i)*Phi*sign(s);

            trig(i) = 1;

            % Reset sampled error
            stil = zeros(3,1);

            nsk2 = s.'*s;


            % =========================================================
            % CASE 3
            % Self-trigger equation (26)
            % =========================================================

            if mode == 3

                ns = sqrt(nsk2);

                % -----------------------------------------------------
                % Equation (26)
                %
                % Factor 2 is included in the denominator.
                % -----------------------------------------------------

                den = 2*nJinv(i) * ...
                    ( ...
                    (n+1)*k1(i)*ns ...
                    + ((n+1)*k2(i) + 1)*alpha(i)*Phi ...
                    );


                % -----------------------------------------------------
                % Solve the implicit t_{k+1} expression using
                % fixed-point iteration.
                %
                % This implementation is compatible with the
                % MATLAB Function block / code generation.
                % -----------------------------------------------------

                tk1 = t;

                for it = 1:60

                    num = sqrt( ...
                        delta(i)*nsk2 ...
                        + chi0(i)* ...
                        exp(-(beta1(i)+beta2(i))*tk1) ...
                        + epsi(i) ...
                        );

                    tk1 = t + num/den;

                end


                % -----------------------------------------------------
                % Ensure the next trigger is at least one simulation
                % sample into the future.
                % -----------------------------------------------------

                if tk1 < t + Ts

                    tk1 = t + Ts;

                end

                tNext(i) = tk1;

            end

        end


        % =============================================================
        % Dynamic variable chi_i
        % =============================================================

        if mode == 2

            chid = ...
                -beta1(i)*chi(i) ...
                + beta2(i)*( ...
                    delta(i)*nsk2 ...
                    + epsi(i) ...
                    - stil.'*stil ...
                    );

            % Numerical integration
            chi(i) = chi(i) + Ts*chid;

        else

            % Self-triggered case
            chi(i) = ...
                chi0(i)* ...
                exp(-(beta1(i)+beta2(i))*t);

        end

    end

end


% ===================== Update persistent outputs ========================

uHold   = u;
chi_out = chi;

end


% ========================================================================
% Reference trajectory
% ========================================================================

function [sd, od] = sff_ref_local(t)
%#codegen

% Reference attitude
%
% sigma_d =
% [3 + 2sin(0.1t)
%  5 + 3cos(0.2t)
% -2 + cos(0.1t)] * 10^-3

sd = [ ...
     3 + 2*sin(0.1*t)
     5 + 3*cos(0.2*t)
    -2 + cos(0.1*t)] * 1e-3;


% Time derivative

sdd = [ ...
     0.2*cos(0.1*t)
    -0.6*sin(0.2*t)
    -0.1*sin(0.1*t)] * 1e-3;


% MRP kinematics:
%
% sigma_dot = G(sigma) omega
%
% omega_d = G(sigma_d)^(-1) sigma_dot_d

G = ...
    0.25*(1 - (sd.'*sd))*eye(3) ...
    + 0.5*sff_skew_local(sd) ...
    + 0.5*(sd*sd.');

od = G \ sdd;

end


% ========================================================================
% Skew-symmetric matrix
% ========================================================================

function S = sff_skew_local(v)
%#codegen

S = [ ...
       0   -v(3)   v(2)
     v(3)     0  -v(1)
    -v(2)   v(1)     0
    ];

end