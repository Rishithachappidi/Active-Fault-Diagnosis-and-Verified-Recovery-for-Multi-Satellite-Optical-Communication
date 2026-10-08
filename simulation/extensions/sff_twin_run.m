function R = sff_twin_run(mode,C)
% Native RK4 harness; mode 1–3 uses ORIGINAL controller and plant unchanged.
% mode 4 adaptive / mode 5 fault-aware self uses experimental extensions.
if nargin<1,mode=4;end
if nargin<2,C=sff_twin_config();end
base=fileparts(fileparts(mfilename('fullpath')));addpath(base);
clear sff_controller_core sff_twin_controller
rng(C.seed,'twister');P=sff_params();x=sff_x0(P);
if mode<=3,C.Ts=P.Ts;C.Tend=P.Tend;end
N=round(C.Tend/C.Ts);R.t=(0:N)'*C.Ts;R.x=zeros(N+1,24);R.u=zeros(N,12);R.trig=zeros(N,4);R.severity=zeros(N,4);R.evidence=zeros(N,4);R.attempts=zeros(N,4);R.delivered=zeros(N,4);R.next=zeros(N,4);R.x(1,:)=x';
for k=1:N
 t=(k-1)*C.Ts;h=C.Ts;
 if mode<=3
  [u,trig]=sff_controller_core(t,x,mode);plant=@(tt,xx)sff_plant_core(tt,xx,max(-.2,min(.2,u)));
 else
  [u,trig,~,~,severity,evidence,attempts,delivered,next]=sff_twin_controller(t,x,mode,C);
  R.severity(k,:)=severity';R.evidence(k,:)=evidence';R.attempts(k,:)=attempts';R.delivered(k,:)=delivered';R.next(k,:)=next';
  plant=@(tt,xx)sff_twin_plant(tt,xx,u,C);
 end
 a=plant(t,x);b=plant(t+h/2,x+h*a/2);c=plant(t+h/2,x+h*b/2);d=plant(t+h,x+h*c);
 x=x+h*(a+2*b+2*c+d)/6;assert(all(isfinite(x))&&max(abs(x))<100,'Numerical divergence');
 R.x(k+1,:)=x';R.u(k,:)=u';R.trig(k,:)=trig';
end
R.config=C;R.mode=mode;R.metrics=sff_twin_metrics(R);
end
