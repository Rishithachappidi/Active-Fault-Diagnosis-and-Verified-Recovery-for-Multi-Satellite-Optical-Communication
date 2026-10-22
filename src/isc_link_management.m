function m=isc_link_management(power,offset,gain,valid,p0,n)
% LOCAL OBSERVATIONS + NOMINAL LIMITS ONLY. No truth or session-up input.
m.severity=max(0,min(1,1-power/p0));m.feasible=-1;m.bestPower=NaN;
if valid
    residual=max(0,norm(offset)-n.maxCorrection);
    m.bestPower=p0*gain*exp(-2*residual^2/n.divergence^2);
    m.feasible=double(m.bestPower>=1.1*n.threshold);
end
if power>=1.2*n.threshold
    m.state=0;
elseif ~valid
    m.state=1; % degraded, cause/feasibility uncertain
elseif m.feasible
    m.state=2; % degraded, fitted correction estimated feasible
else,m.state=3;end % fitted model estimates steering insufficient
end
