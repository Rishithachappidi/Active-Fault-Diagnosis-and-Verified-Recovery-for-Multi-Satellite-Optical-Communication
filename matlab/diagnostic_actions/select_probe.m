function [a,score]=select_probe(o,c)
% Candidate amplitudes scored by worst-axis squared log-power separation
% between offset (+/- divergence/2) and scalar-power hypotheses.
amps=[0 0.5 1]*c.probeAmplitude;
noise=max(c.powerNoise,0.005);scores=-inf(size(amps));
for k=1:numel(amps)
 A=amps(k); separation=2*A/c.divergence;
 loss=1-exp(-2*(A/c.divergence)^2);
 feasible=norm(o.reference)+A<=c.maxCorrection && A/c.probeDwell<c.rateMax/2;
 if feasible,scores(k)=separation^2/noise^2-10*loss;end
end
[score,k]=max(scores);a=amps(k);
% Do not disturb a healthy link or spend a probe on a dark receiver.
[p0,~,~]=optical_power([0;0],1,false,c);
if o.power>c.detectRatio*p0 || o.power<0.01*p0,a=0;score=0;end
end

