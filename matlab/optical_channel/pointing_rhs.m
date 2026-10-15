function [dx,y]=pointing_rhs(t,x,u,c,j)
% State: theta(2), omega(2), delivered torque(2), integral error(2).
k=min(size(c.noiseSamples,1),max(1,floor((t+1e-9)/c.dt)+1));
z=reshape(c.noiseSamples(k,j,:),5,1);
theta=x(1:2);v=x(3:4);a=x(5:6);r=u(1:2);
ym=theta+u(7:8)+c.noise*u(11)*z(1:2);vm=v+c.noise*2*z(3:4);
e=ym-r;s=vm+c.lambda*e;
if strcmp(c.controller,'PID')
 raw=c.J*(-c.kp*e-c.kd*vm-c.ki*x(7:8))+c.b*vm;
else
 raw=c.b*vm-c.J*c.lambda*vm-c.J*c.K*max(-1,min(1,s/c.phi));
end
cmd=max(-c.umax,min(c.umax,raw));
dv=(a-c.b*v)/c.J;
dv(abs(v)>=c.rateMax & sign(v).*dv>0)=0;
di=e;di(abs(raw)>c.umax)=0;
dx=[max(-c.rateMax,min(c.rateMax,v));dv;(u(3)*cmd-a)/(c.tau*u(4));di];
[p,q,av]=optical_power(theta+u(9:10),u(5),u(6)>0,c);
pm=max(0,p*(1+c.powerNoise*z(5)));
% 26 signals; ground truth is deliberately excluded from sensor_view.
y=[r;theta;theta+u(9:10);v;s;cmd;a;double(any(abs(raw)>c.umax));p;q;double(av);ym;vm;pm;u(3);u(4);u(5)];
end

