function y=isc_math(op,a,b)
% Scalar-first Hamilton quaternions map body vectors into inertial axes.
switch op
case 'mul'
    y=[a(1)*b(1)-dot(a(2:4),b(2:4));a(1)*b(2:4)+b(1)*a(2:4)+cross(a(2:4),b(2:4))];
case 'conj', y=[a(1);-a(2:4)];
case 'exp'
    n=norm(a); if n<1e-12, y=[1;a/2]; else, y=[cos(n/2);sin(n/2)*a/n]; end
    y=y/norm(y);
case 'log'
    a=a/norm(a); if a(1)<0,a=-a;end
    n=norm(a(2:4)); if n<1e-12,y=2*a(2:4);else,y=2*atan2(n,a(1))*a(2:4)/n;end
case 'rot'
    v=a(2:4); y=(a(1)^2-dot(v,v))*eye(3)+2*(v*v')+2*a(1)*[0 -v(3) v(2);v(3) 0 -v(1);-v(2) v(1) 0];
otherwise, error('Unknown operation');
end
end
