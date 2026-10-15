function [dx,y]=terminal_kernel(x,u,z,p)
%#codegen
J=p(1);b=p(2);tau=p(3);umax=p(4);vmax=p(5);
theta=x(1:2);v=x(3:4);a=x(5:6);r=u(1:2);
ym=theta+u(7:8)+p(13)*u(11)*z(1:2);vm=v+p(13)*2*z(3:4);
e=ym-r;s=vm+p(6)*e;
if p(15)>0
 raw=J*(-p(9)*e-p(10)*vm-p(11)*x(7:8))+b*vm;
else
 raw=b*vm-J*p(6)*vm-J*p(7)*max(-1,min(1,s/p(8)));
end
cmd=max(-umax,min(umax,raw));
dv=(a-b*v)/J;
for k=1:2
 if abs(v(k))>=vmax && sign(v(k))*dv(k)>0,dv(k)=0;end
end
di=e;for k=1:2,if abs(raw(k))>umax,di(k)=0;end,end
dx=[max(-vmax,min(vmax,v));dv;(u(3)*cmd-a)/(tau*u(4));di];
err=theta+u(9:10);
power=p(12)*exp(-2*sum(err.^2)/p(16)^2)*max(0,u(5))*double(u(6)<=0);
q=power/p(17);pm=max(0,power*(1+p(14)*z(5)));
y=[r;theta;err;v;s;cmd;a;double(any(abs(raw)>umax));power;q;double(q>=1);ym;vm;pm;u(3);u(4);u(5)];
end

