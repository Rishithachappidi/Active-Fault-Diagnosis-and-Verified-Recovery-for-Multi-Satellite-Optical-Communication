function p=isc_frozen_policy(state,valid,powerFraction,offsetMagnitude,age,rateChange,n)
% Frozen after development seeds 11,23,47; never receives fault truth.
% No fast retries. Throttle only a valid fit that estimates infeasibility.
p.retryGap=n.eventMax;
if state==3 && valid,p.retryGap=n.infeasibleGap;end
p.horizon=n.staleLimit;
evidence=(state==1 && powerFraction>=0.01) ||...
    (state==2 && valid && offsetMagnitude>=0.20*n.divergence);
if evidence && age>=n.staleLimit && age<n.managedHorizon &&...
        isfinite(rateChange) && rateChange<=3e-4
    p.horizon=n.managedHorizon;
end
end
