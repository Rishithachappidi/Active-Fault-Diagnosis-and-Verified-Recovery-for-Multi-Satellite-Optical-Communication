function p=terminal_parameters(c)
p0=optical_power([0;0],1,false,c);
p=[c.J;c.b;c.tau;c.umax;c.rateMax;c.lambda;c.K;c.phi;c.kp;c.kd;c.ki;p0;c.noise;c.powerNoise;double(strcmp(c.controller,'PID'));c.divergence;c.sensitivity];
end

