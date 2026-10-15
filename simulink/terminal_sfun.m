function terminal_sfun(block)
setup(block);
end
function setup(b)
b.NumDialogPrms=2;b.NumInputPorts=1;b.NumOutputPorts=1;
b.SetPreCompInpPortInfoToDynamic;b.SetPreCompOutPortInfoToDynamic;
b.InputPort(1).Dimensions=11;b.InputPort(1).DirectFeedthrough=true;
b.OutputPort(1).Dimensions=26;b.NumContStates=8;b.SampleTimes=[0 0];
b.SimStateCompliance='DefaultSimState';
b.RegBlockMethod('InitializeConditions',@init);b.RegBlockMethod('Outputs',@out);b.RegBlockMethod('Derivatives',@deriv);
end
function init(b)
c=b.DialogPrm(1).Data;b.ContStates.Data=[c.initialAngle;zeros(6,1)];
end
function out(b)
[~,y]=pointing_rhs(b.CurrentTime,b.ContStates.Data,b.InputPort(1).Data,b.DialogPrm(1).Data,b.DialogPrm(2).Data);b.OutputPort(1).Data=y;
end
function deriv(b)
[dx,~]=pointing_rhs(b.CurrentTime,b.ContStates.Data,b.InputPort(1).Data,b.DialogPrm(1).Data,b.DialogPrm(2).Data);b.Derivatives.Data=dx;
end

