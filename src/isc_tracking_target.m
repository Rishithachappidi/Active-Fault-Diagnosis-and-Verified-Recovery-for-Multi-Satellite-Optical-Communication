function [qd,wd,age]=isc_tracking_target(i,cache,rate,stamp,t,n)
% Neighbor-essential reference wrapper. No current neighbor truth is read.
if i==1
    [qr,wr]=isc_reference(t,n.referencePhase);
    qd=isc_math('mul',qr,n.offsets(:,1));
    wd=isc_math('rot',n.offsets(:,1))'*wr;age=0;return;
end
j=n.parent(i);age=max(0,t-stamp(j,i));
if stamp(j,i)<0
    qd=n.holdQ(:,i);wd=zeros(3,1);return;
end
qp=cache(:,j,i);wp=rate(:,j,i);horizon=n.predictionHorizon(i);
if n.predict
    qp=isc_math('mul',qp,isc_math('exp',wp*min(age,horizon)));
    if age>=horizon,wp=zeros(3,1);end
else,wp=zeros(3,1);end
relative=isc_math('mul',isc_math('conj',n.offsets(:,j)),n.offsets(:,i));
qd=isc_math('mul',qp,relative);wd=isc_math('rot',relative)'*wp;
end
