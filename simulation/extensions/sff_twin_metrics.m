function M=sff_twin_metrics(R)
% Full-rate, half-open integration. MRP component difference norm.
t=R.t;h=t(2)-t(1);T=t(end);[sd,od]=sff_ref(t);N=numel(t);ae=zeros(N,4);we=ae;
for i=1:4,ae(:,i)=sqrt(sum((R.x(:,6*i-5:6*i-3)-sd').^2,2));we(:,i)=sqrt(sum((R.x(:,6*i-2:6*i)-od').^2,2));end
M.attitudeRMSE=sqrt(sum(sum(ae(1:end-1,:).^2))*h/(4*T));M.angularVelocityRMSE=sqrt(sum(sum(we(1:end-1,:).^2))*h/(4*T));
M.maxAttitudeError=max(ae,[],'all');M.controllerUpdates=sum(R.trig,'all');
if R.mode<=3,M.communicationEvents=M.controllerUpdates;else,M.communicationEvents=sum(R.attempts(end,:));end
M.controlEffort=sum(max(-.2,min(.2,R.u)).^2,'all')*h;M.saturationPercent=100*mean(abs(R.u)>.2,'all');M.peakTorque=max(abs(max(-.2,min(.2,R.u))),[],'all');
v=find(any(ae>.02|we>.01,2),1,'last');settled=0;if ~isempty(v),settled=min(T,t(v)+h);end
M.success=T-settled>=2;M.convergenceTime=NaN;if M.success,M.convergenceTime=settled;end
M.faultRecoveryTime=NaN;
if R.mode>3
 f=R.config.faults;active=f(:,1)>0;
 if any(active),lastFault=max(f(active,2)+f(active,3).*double(f(active,4)==2));if M.success&&T>=lastFault+2,M.faultRecoveryTime=max(0,settled-lastFault);end,end
end
end
