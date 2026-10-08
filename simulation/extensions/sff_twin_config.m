function C = sff_twin_config()
% Separate experimental configuration. Does not mutate sff_params.
C.Ts = 0.001; C.Tend = 60; C.seed = 42; C.budget = 500;
C.r = 0.6; C.k0 = 0.1; C.alpha = 0.001; C.delta = 0.3;
C.epsilon = 1e-4; C.chi0 = 0.3; C.beta1 = 5; C.beta2 = 10;
C.gamma = 0.5; C.gainScale = 1; C.errorWeight = 4;
C.faultWeight = 3; C.disturbanceWeight = 1; C.commWeight = 1;
C.maxInterval = 1; C.dropout = 0.2; C.noise = 0;
C.disturbanceScale = 3; C.disturbanceTime = 20;
C.J = [5.1 4.8 5;4.9 4.9 5.1;5 5.2 5.1;4.8 5.1 4.9];
C.initialGamma = ones(4,3);
% Up to four profiles. Columns: spacecraft (1-based), onset, duration,
% kind (1 sudden, 2 gradual, 3 intermittent), target X/Y/Z, period.
% spacecraft=0 disables a row.
C.faults = [2 20 10 1 .45 .35 .5 4;zeros(3,8)];
end
