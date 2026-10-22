function isc_sfunction(b)
% Genuine live discrete simulation: executes isc_step, not result playback.
b.NumDialogPrms=1;b.NumInputPorts=0;b.NumOutputPorts=1;
b.SetPreCompOutPortInfoToDynamic;b.OutputPort(1).Dimensions=120;
c=b.DialogPrm(1).Data;b.SampleTimes=[c.dt 0];
b.SimStateCompliance='DefaultSimState';
b.RegBlockMethod('PostPropagationSetup',@work);
b.RegBlockMethod('InitializeConditions',@init);
b.RegBlockMethod('Outputs',@output);
b.RegBlockMethod('Update',@update);
end
function work(b)
c=b.DialogPrm(1).Data;b.NumDworks=2;
b.Dwork(1).Name='CoupledState';b.Dwork(1).Dimensions=numel(isc_pack(isc_init(c)));
b.Dwork(2).Name='Telemetry';b.Dwork(2).Dimensions=120;
for h=1:2
    b.Dwork(h).DatatypeID=0;b.Dwork(h).Complexity='Real';b.Dwork(h).UsedAsDiscState=true;
end
end
function init(b)
c=b.DialogPrm(1).Data;rng(c.seed,'twister');
b.Dwork(1).Data=isc_pack(isc_init(c));b.Dwork(2).Data=zeros(120,1);
end
function output(b)
b.OutputPort(1).Data=b.Dwork(2).Data;
end
function update(b)
c=b.DialogPrm(1).Data;s=isc_pack(b.Dwork(1).Data,isc_init(c));
[s,z]=isc_step(s,b.CurrentTime,round(b.CurrentTime/c.dt)+1,c);
b.Dwork(1).Data=isc_pack(s);b.Dwork(2).Data=isc_telemetry(z);
end
