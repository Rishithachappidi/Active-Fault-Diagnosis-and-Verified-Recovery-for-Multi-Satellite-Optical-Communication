function target=isc_target(q,c,a)
% Two-axis terminal mount is nominally aimed along its neighbor's LOS.
i=c.sender(a); j=c.receiver(a);
los=c.positions(:,j)-c.positions(:,i); los=los/norm(los);
z=[0;0;1]; y=cross(z,los); y=y/norm(y); B=[los y z];
R=isc_math('rot',q); v=B'*(R'*los);
target=[atan2(v(2),v(1));atan2(v(3),hypot(v(1),v(2)))];
end
