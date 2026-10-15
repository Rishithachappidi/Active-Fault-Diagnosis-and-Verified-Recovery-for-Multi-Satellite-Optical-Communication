function [p,q,available]=optical_power(theta,scale,blocked,c)
% Small receiver approximation to displaced far-field Gaussian beam.
w=c.distance*c.divergence; a=c.aperture/2;
p=c.Pt*c.eta*(1-exp(-2*a*a/(w*w)))*exp(-2*sum(theta.^2)/c.divergence^2)*max(0,scale)*(~blocked);
q=p/c.sensitivity; available=q>=1;
end

