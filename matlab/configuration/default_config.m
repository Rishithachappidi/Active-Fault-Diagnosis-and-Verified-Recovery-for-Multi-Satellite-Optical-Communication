function c=default_config(n)
if nargin<1,n=4;end
c.n=n; c.topology='mesh'; c.seed=101; c.dt=0.02; c.T=10;
c.J=0.002; c.b=0.004; c.tau=0.08; c.umax=2e-6; c.rateMax=120e-6;
c.lambda=8; c.K=80e-6; c.phi=8e-6; c.kp=64; c.kd=14; c.ki=8;
c.initialAngle=[2;-1]*1e-6; c.noise=0.08e-6; c.powerNoise=0.008;
c.Pt=0.5; c.eta=0.4; c.divergence=20e-6; c.aperture=0.10;
c.distance=800e3; c.sensitivity=1.5e-6; c.capacity=1e9;
c.offered=0.6e9; c.packetBits=12000; c.c=299792458; c.processing=1e-4;
c.method='proposed'; c.controller='SMC'; c.scenario='normal';
c.faultStart=2; c.faultEnd=8; c.profile='sudden'; c.severity=1;
c.probeAmplitude=6e-6; c.probeDwell=0.5; c.maxCorrection=35e-6;
c.detectRatio=0.72; c.decisionPeriod=0.1; c.warmup=1;
c.edges=make_network(n,c.topology,c.seed); c.m=size(c.edges,1);
c.version='1.0.0'; c.assumptions='Fixed sparse graph; one effective two-axis terminal per bidirectional edge; fluid single flow 1 to 2; no orbital propagation or atmospheric loss.';
end

