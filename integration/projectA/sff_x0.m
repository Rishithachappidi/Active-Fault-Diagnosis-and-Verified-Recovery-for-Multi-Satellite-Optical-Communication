function x0 = sff_x0(P)
%SFF_X0  Pack the initial conditions of Section IV into the 24x1 state
%   vector used by the Integrator block:
%   x = [sigma_1; omega_1; sigma_2; omega_2; sigma_3; omega_3; sigma_4; omega_4]
if nargin < 1, P = sff_params(); end
x0 = zeros(24,1);
for i = 1:4
    x0(6*(i-1)+1 : 6*(i-1)+3) = P.sigma0(:,i);
    x0(6*(i-1)+4 : 6*(i-1)+6) = P.omega0(:,i);
end
end
