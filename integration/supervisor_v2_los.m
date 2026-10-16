function supervisor_v2_los(b)
% INTEGRATION COPY of revisions/v2/supervisor_v2.m. Only change: a second
% input port carries the known attitude-induced LOS offset d (2 per link,
% from the coarse-pointing loop, onboard telemetry, not fault truth), which is
% added to the kinematic angle used by the optical power model. With d = 0
% this is identical to the original V2 supervisor.
b.NumDialogPrms=1;c=b.DialogPrm(1).Data;
b.NumInputPorts=2;b.NumOutputPorts=3;b.SetPreCompInpPortInfoToDynamic;b.SetPreCompOutPortInfoToDynamic;
b.InputPort(1).Dimensions=26*c.m;b.InputPort(1).DirectFeedthrough=false;
b.InputPort(2).Dimensions=2*c.m;b.InputPort(2).DirectFeedthrough=false;
b.OutputPort(1).Dimensions=11*c.m;b.OutputPort(2).Dimensions=8*c.m+4;b.OutputPort(3).Dimensions=16*c.m;
b.SampleTimes=[c.dt 0];b.SimStateCompliance='DefaultSimState';
b.RegBlockMethod('PostPropagationSetup',@work);b.RegBlockMethod('InitializeConditions',@init);
b.RegBlockMethod('Outputs',@out);b.RegBlockMethod('Update',@update);
end
function work(b)
c=b.DialogPrm(1).Data;b.NumDworks=5;
names={'state','commands','logs','history','estimates'};dims=[30*c.m 11*c.m 8*c.m+4 8*150*c.m 16*c.m];
for k=1:5,b.Dwork(k).Name=names{k};b.Dwork(k).Dimensions=dims(k);b.Dwork(k).DatatypeID=0;b.Dwork(k).Complexity='Real';b.Dwork(k).UsedAsDiscState=true;end
end
function init(b)
c=b.DialogPrm(1).Data;for k=1:5,b.Dwork(k).Data=zeros(b.Dwork(k).Dimensions,1);end
u=zeros(11,c.m);for j=1:c.m,u(:,j)=fault_input(0,j,c);end;b.Dwork(2).Data=u(:);
end
function out(b)
b.OutputPort(1).Data=b.Dwork(2).Data;b.OutputPort(2).Data=b.Dwork(3).Data;b.OutputPort(3).Data=b.Dwork(5).Data;
end
function update(b)
c=b.DialogPrm(1).Data;dc=v2_nominal(c);t=b.CurrentTime;
Y=reshape(b.InputPort(1).Data,26,c.m);DL=reshape(b.InputPort(2).Data,2,c.m);S=reshape(b.Dwork(1).Data,30,c.m);
B=reshape(b.Dwork(4).Data,8,150,c.m);U=zeros(11,c.m);L=zeros(8,c.m);E=zeros(16,c.m);
for j=1:c.m
 o=sensor_view(Y(:,j));o.los=DL(:,j);k=mod(S(24,j),150)+1;S(24,j)=k;S(23,j)=min(150,S(23,j)+1);
 % Predict kinetic angle for this sample for optical history only.
 if S(7,j)==0,q=o.angle;else,q=S(1:2,j)+c.dt*(S(5:6,j)+o.rate)/2;end
 B(:,k,j)=[t;q+o.los;o.power;o.command;o.delivered];   % optical fit sees LOS angle
 H=B(:,1:S(23,j),j);[~,order]=sort(H(1,:));H=H(:,order);
 [s,ref,label,action,probe]=v2_decision_step_los(t,o,S(:,j),H,dc);S(:,j)=s;
 [u,truth]=fault_input(t+c.dt,j,c);u(1:2)=ref;U(:,j)=u;
 L(:,j)=[label;double(label==7);action;truth;ref-probe-[1;0.5]*1e-6*sin(2*t);double(any(probe));Y(18,j)];
 E(:,j)=[s(1:4);s(11:13);s(17:22);s(29);s(9);s(30)];
end
r=route_network(c,Y(18,:)>0,Y(16,:),Y(17,:));lat=r.latency;if isnan(lat),lat=-1;end
b.Dwork(1).Data=S(:);b.Dwork(2).Data=U(:);b.Dwork(3).Data=[L(:);r.throughput;lat;r.pdr;numel(r.edgeIDs)];
b.Dwork(4).Data=B(:);b.Dwork(5).Data=E(:);
end
