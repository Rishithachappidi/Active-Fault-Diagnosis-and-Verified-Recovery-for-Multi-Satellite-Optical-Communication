function [s,ref,label,action,probe]=v2_decision_step_los(t,o,s,B,c)
% INTEGRATION COPY of revisions/v2/v2_decision_step.m. Only change: the
% optical power prediction uses kinematic angle + o.los (known attitude-induced
% LOS offset). With o.los = 0 it is identical to the original.
% Only observable sensors, estimator state, history and WHITELISTED nominal
% parameters enter. No scenario, truth label, fault times or severity.
% s 1:2 kinetic angle;3:4 bias;5:6 previous rate;7 initialized;
% 8 probe start;9 mode;10 valid fit;11:12 offset;13 gain;
% 14 mismatch counter;15 last reset;16 label;17 eta;18 tau;19 actuator class;
% 20 actuator residual;21 optical condition;22 optical residual;23 count;
% 24 circular index;25 last update;26 healthy timer;27 probe amplitude;
% 28 last probe end;29 actuator condition;30 verified restoration.
if s(7)==0
 s(1:2)=o.angle;s(5:6)=o.rate;s(7)=1;s(13)=1;s(18)=c.tau;
else
 s(1:2)=s(1:2)+c.dt*(s(5:6)+o.rate)/2;s(5:6)=o.rate;
end
s(3:4)=0.5*s(3:4)+0.5*(o.angle-s(1:2));
label=s(16);action=0;probe=[0;0];
if t<1,ref=[1;0.5]*1e-6*sin(2*t);return;end
[p0,~,~]=optical_power([0;0],1,false,c);
decision=mod(round(t/c.dt),round(c.decisionPeriod/c.dt))==0;
biasFlag=norm(s(3:4))>c.biasThreshold;
if decision
 [act,eta,tau,condition,err]=v2_actuator_fit(B(:,B(1,:)>=t-c.fitWindow),c);
 s(17)=finite_or(eta,1);s(18)=finite_or(tau,c.tau);s(19)=act;
 s(20)=finite_or(err,1e6);s(29)=condition;
 % Validate an existing optical fit against CURRENT measurements.
 expected=p0*s(13)*exp(-2*sum((s(1:2)+o.los+s(11:12)).^2)/c.divergence^2);
 mismatch=abs(log(max(o.power,0.001*p0)/max(expected,0.001*p0)))>0.35;
 if s(10)>0 && mismatch,s(14)=s(14)+1;else,s(14)=0;end
 if s(14)>=2
  % Roll back stale optical correction and collect independent confirmation.
  s(10)=0;s(11:12)=0;s(13)=1;s(9)=-1;s(15)=t;s(14)=0;s(30)=0;action=5;
 end
end
nominal=p0*exp(-2*sum((s(1:2)+o.los).^2)/c.divergence^2);
optResidual=abs(log(max(o.power,0.001*p0)/max(nominal,0.001*p0)));
dark=o.power<0.005*p0;
if s(9)==-1 && t-s(15)>=c.cooldown,s(9)=0;end
if decision && s(9)==0 && s(10)==0 && optResidual>0.35 && ~dark
 probeObservation=o;
 % select_probe's power check uses observed degradation; residual can also
 % reveal attenuation while a link is still operational.
 probeObservation.power=min(o.power,0.7*p0);probeObservation.reference=[0;0];
 [amp,~]=select_probe(probeObservation,c);
 torqueBound=c.J*4*amp/c.probeDwell^2+c.b*2*amp/c.probeDwell;
 if amp>0 && torqueBound<c.umax
  s(9)=1;s(8)=t;s(27)=amp;s(10)=0;s(30)=0;
 end
end
if s(9)==1
 elapsed=t-s(8);phase=min(4,floor(elapsed/c.probeDwell)+1);
 dirs=[1 -1 0 0;0 0 1 -1];probe=s(27)*dirs(:,phase);action=2;
 if decision && elapsed>=1.4
  age=B(1,:)-s(8);select=age>=0 & mod(age,c.probeDwell)>0.12;
  [ok,offset,gain,cond,err]=v2_optical_fit(B(:,select),c);
  s(21)=cond;s(22)=finite_or(err,1e6);
  if ok
   s(11:12)=offset;s(13)=gain;s(10)=1;s(9)=2;s(28)=t;probe=[0;0];action=3;
  elseif elapsed>=4*c.probeDwell
   s(9)=-1;s(15)=t;s(28)=t;probe=[0;0];action=1;
  end
 end
end
offsetFlag=s(10)>0 && norm(s(11:12))>c.offsetThreshold;
gainFlag=s(10)>0 && s(13)<c.gainThreshold;
act=s(19);
if dark
 label=7;
elseif s(9)==1 || (s(10)==0 && optResidual>0.35)
 label=7;
elseif offsetFlag && gainFlag && ~biasFlag && act==0
 label=8;
elseif (double(offsetFlag)+double(gainFlag)+double(biasFlag)+double(act~=0))>1
 label=7;
elseif biasFlag
 label=6;
elseif offsetFlag
 label=1;
elseif gainFlag
 label=4;
elseif act==2 || act==3
 label=act;
elseif act==7 && s(29)>=2e-4 && s(20)<0.5
 % A well-conditioned but conflicting actuator fit is uncertain, not healthy.
 label=7;
else
 label=0;
end
% Remove small estimator noise from the control correction.
bias=[0;0];offset=[0;0];
if biasFlag,bias=s(3:4);end
% Do not apply a correction that cannot restore service even at perfect
% alignment. In that case preserve the diagnosis but use network rerouting.
if offsetFlag && p0*s(13)>=1.05*c.sensitivity,offset=s(11:12);end
correction=bias-offset;
if norm(correction)>c.maxCorrection,correction=correction*c.maxCorrection/norm(correction);end
ref=correction+probe+[1;0.5]*1e-6*sin(2*t);
if norm(ref)>c.maxCorrection,ref=ref*c.maxCorrection/norm(ref);end
if norm(correction)>0 && action==0,action=3;end
if dark && action==0,action=1;end
if o.power>=c.sensitivity
 s(26)=s(26)+c.dt;
 if s(26)>=0.5,s(30)=1;end
else,s(26)=0;s(30)=0;end
s(16)=label;
end
function x=finite_or(x,replacement)
if ~isfinite(x),x=replacement;end
end
