function supervisor_sfun(b)
b.NumDialogPrms=1;c=b.DialogPrm(1).Data;
b.NumInputPorts=1;b.NumOutputPorts=2;b.SetPreCompInpPortInfoToDynamic;b.SetPreCompOutPortInfoToDynamic;
b.InputPort(1).Dimensions=26*c.m;b.InputPort(1).DirectFeedthrough=false;
b.OutputPort(1).Dimensions=11*c.m;b.OutputPort(2).Dimensions=8*c.m+4;
b.SampleTimes=[c.dt 0];b.SimStateCompliance='DefaultSimState';
b.RegBlockMethod('PostPropagationSetup',@work);b.RegBlockMethod('InitializeConditions',@init);
b.RegBlockMethod('Outputs',@out);b.RegBlockMethod('Update',@update);
end
function work(b)
c=b.DialogPrm(1).Data;b.NumDworks=4;
names={'states','commands','logs','fitData'};dims=[12*c.m 11*c.m 8*c.m+4 4*200*c.m];
for k=1:4,b.Dwork(k).Name=names{k};b.Dwork(k).Dimensions=dims(k);b.Dwork(k).DatatypeID=0;b.Dwork(k).Complexity='Real';b.Dwork(k).UsedAsDiscState=true;end
end
function init(b)
c=b.DialogPrm(1).Data;for k=1:4,b.Dwork(k).Data=zeros(b.Dwork(k).Dimensions,1);end
u=zeros(11,c.m);for j=1:c.m,u(:,j)=fault_input(0,j,c);end;b.Dwork(2).Data=u(:);
end
function out(b)
b.OutputPort(1).Data=b.Dwork(2).Data;b.OutputPort(2).Data=b.Dwork(3).Data;
end
function update(b)
c=b.DialogPrm(1).Data;dc=diagnostic_config(c);t=b.CurrentTime;
Y=reshape(b.InputPort(1).Data,26,c.m);S=reshape(b.Dwork(1).Data,12,c.m);
U=reshape(b.Dwork(2).Data,11,c.m);L=reshape(b.Dwork(3).Data(1:8*c.m),8,c.m);
F=reshape(b.Dwork(4).Data,4,200,c.m);
isDecision=mod(round(t/c.dt),round(c.decisionPeriod/c.dt))==0;
active=ismember(c.method,{'proposed','no_recovery'});
guided=ismember(c.method,{'proposed','residual','pid','no_active'});
[p0,~,~]=optical_power([0;0],1,false,c);
for j=1:c.m
 o=sensor_view(Y(:,j));
 if isDecision && t>=c.warmup
  prev=struct('delivered',S(7:8,j));d=passive_diagnosis(o,prev,dc);
  S(7:8,j)=o.delivered;L(1,j)=d.label;L(2,j)=double(d.uncertain);
  % S: correction2, start, amplitude, fitCount, attempted, prevTorque2, fitLabel, fitGain, offset2.
  if S(6,j)==0 && d.label~=0
   if active,[A,~]=select_probe(o,dc);else,A=0;end
   if A>0,S(3,j)=t;S(4,j)=A;S(6,j)=1;end
   % Conservative baseline: reset to nominal alignment once; do not infer
   % a hidden optical offset from an encoder tracking its own setpoint.
   if guided && ~active
    S(1:2,j)=[0;0];L(3,j)=3;S(6,j)=-1;
   end
  end
 end
 probe=[0;0];elapsed=t-S(3,j);
 if S(6,j)==1 && S(4,j)>0
  phase=floor(elapsed/c.probeDwell)+1;
  directions=[1 -1 0 0;0 0 1 -1];
  if phase<=4
   probe=S(4,j)*directions(:,max(1,phase));L(3,j)=2;
   if isDecision && mod(elapsed,c.probeDwell)>0.15 && o.power>0.005*p0
    k=min(200,S(5,j)+1);S(5,j)=k;
    F(:,k,j)=[1;o.angle/c.divergence;log(o.power/p0)+2*sum(o.angle.^2)/c.divergence^2];
   end
  else
   k=S(5,j);X=squeeze(F(1:3,1:k,j))';z=reshape(F(4,1:k,j),[],1);
   [label,offset,gain,~]=active_fit(X,z,dc);S(9,j)=label;S(10,j)=gain;S(11:12,j)=offset;
   [corr,action]=recovery_decision(label,offset,gain,dc);
   S(1:2,j)=corr;L(3,j)=action;S(6,j)=2;
  end
 end
 if S(6,j)==2,L(1,j)=S(9,j);L(2,j)=double(S(9,j)==7);end
 % Inputs are injected here, but only sensor_view is passed to diagnosis.
 [u,truth]=fault_input(t+c.dt,j,c);
 u(1:2)=S(1:2,j)+probe+[1;0.5]*1e-6*sin(2*t);
 if norm(u(1:2))>c.maxCorrection,u(1:2)=u(1:2)*c.maxCorrection/norm(u(1:2));end
 U(:,j)=u;L(4,j)=truth;L(5:6,j)=S(1:2,j);L(7,j)=double(any(probe));L(8,j)=double(Y(18,j)>0);
end
r=route_network(c,Y(18,:)>0,Y(16,:),Y(17,:));
lat=r.latency;if isnan(lat),lat=-1;end
b.Dwork(1).Data=S(:);b.Dwork(2).Data=U(:);b.Dwork(3).Data=[L(:);r.throughput;lat;r.pdr;numel(r.edgeIDs)];b.Dwork(4).Data=F(:);
end

