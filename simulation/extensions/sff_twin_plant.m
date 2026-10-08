function dx = sff_twin_plant(t,x,u,C)
% Nonlinear plant extension. Original sff_plant_core is unchanged.
G=sff_twin_effectiveness(t,C); dx=zeros(24,1);
a=sin(.1*t); b=cos(.2*t); c=cos(.1*t); d=sin(.2*t);
rho=[2+a 1+2*b 2+a;1+2*b 2+a 1+2*b;3+3*c 2+c 2+d;2+d 1+2*d 3+3*c]*1e-3;
ub=[.2+.3*b -.3+.1*c .1-.2*d;-.3+.1*a -.2+.3*b .3-.3*a;-.2+.2*a -.2+.2*cos(.3*t) .2-.1*cos(.3*t);.1+.3*b -.3+.1*d .1-.2*d]*1e-3;
scale=1;if t>=C.disturbanceTime,scale=C.disturbanceScale;end
for i=1:4
 k=6*(i-1);q=3*(i-1);s=x(k+1:k+3);w=x(k+4:k+6);j=C.J(i,:)';
 dx(k+1:k+3)=.25*(1-s'*s)*w+.5*cross(s,w)+.5*s*(s'*w);
 us=max(-.2,min(.2,u(q+1:q+3)));
 dx(k+4:k+6)=(-cross(w,j.*w)+G(i,:)'.*us+ub(i,:)'+scale*rho(i,:)')./j;
end
end
