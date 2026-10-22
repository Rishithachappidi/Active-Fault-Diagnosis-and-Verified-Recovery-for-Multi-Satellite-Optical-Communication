function [d,correction]=isc_diagnose(o,d,n)
% Observable-only supervisor. No injected fault times, severity or truth.
% o.x: terminal encoder angle minus local attitude/geometry pointing target.
% o.power: local reciprocal pilot power / distance-dependent nominal power.
% n contains only nominal optical parameters and sample timing.
d.hindex=mod(d.hindex,n.samples)+1;
d.hx(:,d.hindex)=o.x; d.hp(d.hindex)=o.power;
d.hcount=min(d.hcount+1,n.samples);
correction=d.correction;
if ~o.decision,return;end
expected=d.gain*exp(-2*sum((o.x+d.offset).^2)/n.divergence^2);
if d.valid && abs(log(max(o.power,0.002)/max(expected,0.002)))>0.40
    d.mismatch=d.mismatch+1;
else,d.mismatch=0;end
if d.mismatch>=3
    d.valid=0; d.offset=[0;0]; d.correction=[0;0];
    d.gain=1; d.hcount=0; d.hindex=0; d.mismatch=0;
    % Restart the ring consistently: subsequent fits must use only samples
    % collected AFTER invalidation, never pre-fault slots in a partial ring.
    d.hx(:)=0; d.hp(:)=0;
end
if d.hcount>=max(12,round(0.75*n.samples))
    x=d.hx(:,1:d.hcount); p=d.hp(1:d.hcount);
    good=p>0.01 & p<1.5; x=x(:,good); p=p(good);
    if numel(p)>=12
        X=[ones(numel(p),1), x'/n.divergence];
        z=log(p')+2*sum(x.^2,1)'/n.divergence^2;
        if rcond(X'*X)>2e-4
            beta=X\z; offset=-n.divergence*beta(2:3)/4;
            gain=exp(beta(1)+2*sum(offset.^2)/n.divergence^2);
            fitError=sqrt(mean((X*beta-z).^2));
            if fitError<0.06 && gain>0.02 && gain<1.3 && norm(offset)<2*n.divergence
                d.offset=offset;d.gain=gain;d.valid=1;
            end
        end
    end
end
if o.power<0.005
    d.label=3; % dark/ambiguous: never claim proven blockage
elseif ~d.valid
    d.label=3;
elseif norm(d.offset)>0.20*n.divergence && d.gain<0.70
    d.label=4; % pointing plus attenuation
elseif norm(d.offset)>0.20*n.divergence
    d.label=1;
elseif d.gain<0.70
    d.label=2;
else,d.label=0;end
% Only compensate if the fitted best power could support this link.
if d.valid && d.gain>n.threshold*1.1
    correction=-d.offset;
    correction=correction*min(1,n.maxCorrection/max(norm(correction),eps));
else,correction=[0;0];end
d.correction=correction;
end
