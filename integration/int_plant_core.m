function dx = int_plant_core(t, x, usat, tauExt)
%INT_PLANT_CORE  Project A spacecraft dynamics plus an optional external
%   disturbance torque, used only by the integrated model.
%   Calls the UNMODIFIED Project A plant sff_plant_core (eq. 1-2) and adds
%   J_i^-1 * tauExt_i to each spacecraft's angular acceleration.
%   tauExt : 12x1 [N*m], body frame, bypasses actuator effectiveness Gamma_i.
%#codegen
dx = sff_plant_core(t, x, usat);
Jd = [5.1 4.8 5.0
      4.9 4.9 5.1
      5.0 5.2 5.1
      4.8 5.1 4.9];            % same inertias as sff_params / sff_plant_core
for i = 1:4
    ks = 6*(i-1);
    dx(ks+4:ks+6) = dx(ks+4:ks+6) + tauExt(3*(i-1)+1:3*(i-1)+3) ./ Jd(i,:).';
end
end
