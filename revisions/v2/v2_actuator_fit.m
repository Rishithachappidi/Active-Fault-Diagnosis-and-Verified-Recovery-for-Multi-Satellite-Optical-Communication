function [label,eta,tau,condition,err]=v2_actuator_fit(B,c)
% B rows: t, kinetic angle x/y, power, command x/y, delivered torque x/y.
label=7;eta=NaN;tau=NaN;condition=0;err=Inf;
if size(B,2)<15,return;end
dt=diff(B(1,:));keep=dt>0 & dt<1.1*c.dt;
cmd=B(5:6,1:end-1);a0=B(7:8,1:end-1);a1=B(7:8,2:end);
X=[reshape(cmd(:,keep),[],1) -reshape((a0(:,keep)+a1(:,keep))/2,[],1)];
D=(a1(:,keep)-a0(:,keep))./dt(keep);
y=D(:);scale=max(abs(X),[],'all');
if scale<1e-11,return;end
X=X/scale;y=y/scale;condition=rcond(X'*X);
if condition<2e-4,return;end
beta=X\y;
if beta(2)<=0,return;end
tau=1/beta(2);eta=beta(1)*tau;
err=norm(X*beta-y)/max(norm(y),eps);
if err>0.5 || eta<0.01 || eta>2 || tau<0.01 || tau>2,return;end
gainFault=eta<0.65;lagFault=tau>1.8*c.tau;
if gainFault && ~lagFault,label=2;elseif lagFault && ~gainFault,label=3;
elseif gainFault && lagFault,label=7;else,label=0;end
end
