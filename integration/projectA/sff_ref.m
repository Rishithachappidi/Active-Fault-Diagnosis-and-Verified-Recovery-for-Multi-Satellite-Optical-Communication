function [sd, od] = sff_ref(t)
%SFF_REF  Reference attitude and angular velocity (Section IV).
%   sigma_d = [3+2sin(0.1t), 5+3cos(0.2t), -2+cos(0.1t)]^T * 1e-3
%   omega_d follows from the MRP kinematics (1): sigmadot_d = G(sigma_d)*omega_d
%   t may be a row/column vector; sd and od are 3xN.

t  = t(:).';
N  = numel(t);
sd = [ 3 + 2*sin(0.1*t)
       5 + 3*cos(0.2*t)
      -2 +   cos(0.1*t)]*1e-3;
sdd = [ 0.2*cos(0.1*t)
       -0.6*sin(0.2*t)
       -0.1*sin(0.1*t)]*1e-3;

od = zeros(3,N);
for k = 1:N
    s = sd(:,k);
    G = 0.25*(1 - (s.'*s))*eye(3) + 0.5*[0 -s(3) s(2); s(3) 0 -s(1); -s(2) s(1) 0] ...
        + 0.5*(s*s.');
    od(:,k) = G \ sdd(:,k);
end

end
