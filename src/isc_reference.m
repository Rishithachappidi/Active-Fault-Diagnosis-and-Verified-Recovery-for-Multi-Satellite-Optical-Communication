function [q,w]=isc_reference(t,phase)
% Command generator: called in feedback ONLY by the leader; scoring may call
% it for every spacecraft. Followers have no live reference-command access.
if nargin<2,phase=0;end
q=attitude(t,phase);h=1e-4;
increment=isc_math('mul',isc_math('conj',q),attitude(t+h,phase));
w=isc_math('log',increment)/h;
end
function q=attitude(t,p)
q=isc_math('exp',[.018*sin(.11*t+p);.012*sin(.07*t+.4+p);.010*sin(.09*t-.2+p)]);
end
