function [u,label]=fault_input(t,edge,c)
% Only injection/evaluation layer sees this function's ground truth.
u=[0;0;1;1;1;0;0;0;0;0;1];label=0;
if edge~=1 || t<c.faultStart || (t>=c.faultEnd && ~strcmp(c.profile,'persistent')),return;end
g=c.severity;
switch c.profile
 case 'gradual',g=g*min(1,(t-c.faultStart)/2);
 case 'intermittent',g=g*double(mod(t-c.faultStart,2)<1);
 case {'sudden','persistent'}
 otherwise,error('Unknown fault profile');
end
if g==0,return;end
switch c.scenario
 case 'pointing',u(9:10)=g*[23;10]*1e-6;label=1;
 case 'effectiveness',u(3)=max(0.05,1-0.75*g);label=2;
 case 'lag',u(4)=1+5*g;label=3;
 case 'power',u(5)=max(0.01,1-0.82*g);label=4;
 case 'blockage',u(6)=1;label=5;
 case 'sensor',u(7:8)=g*[23;10]*1e-6;label=6;
 case 'simultaneous',u(9:10)=g*[23;10]*1e-6;u(5)=max(0.01,1-0.65*g);label=8;
 case 'normal'
 otherwise,error('Unknown scenario');
end
end

