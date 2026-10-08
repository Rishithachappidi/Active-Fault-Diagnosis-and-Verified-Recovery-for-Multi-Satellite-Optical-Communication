function sff_test_extensions()
% Native smoke/physics assertions. Requires MATLAB; not executed by Node tests.
C=sff_twin_config();C.faults=[2 10 10 2 0 .5 1 4;zeros(3,8)];
G=sff_twin_effectiveness(5,C);assert(isequal(G(2,:),[1 1 1]));
G=sff_twin_effectiveness(15,C);assert(max(abs(G(2,:)-[.5 .75 1]))<1e-12);
G=sff_twin_effectiveness(20,C);assert(isequal(G(2,:),[0 .5 1]));
x=zeros(24,1);u=ones(12,1);C.disturbanceScale=1;
dx=sff_twin_plant(0,x,u,C);assert(all(isfinite(dx)));
assert(all(dx([1:3 7:9 13:15 19:21])==0));
% Healthy X-axis: saturated .2 + .0005 drift + .002 disturbance.
assert(abs(dx(4)-(.2+.0005+.002)/5.1)<1e-12);
C.Tend=.2;C.Ts=.001;C.dropout=0;C.noise=0;
R=sff_twin_run(4,C);assert(all(isfinite(R.x),'all'));
assert(all(sum(R.trig,1)>=1));assert(all(R.evidence>=0 & R.evidence<=1,'all'));
fprintf('Native extension smoke assertions passed.\n');
end
