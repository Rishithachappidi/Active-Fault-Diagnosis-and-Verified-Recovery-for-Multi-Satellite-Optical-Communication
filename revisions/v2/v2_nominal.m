function d=v2_nominal(c)
d=diagnostic_config(c);
d.dt=c.dt;d.J=c.J;d.b=c.b;d.lambda=c.lambda;d.K=c.K;d.phi=c.phi;
d.biasThreshold=3e-6;d.offsetThreshold=4e-6;d.gainThreshold=0.8;
d.fitWindow=0.8;d.history=150;d.cooldown=0.6;
end
