function [u,trig,chi,sout,severity,evidence,attempts,delivered,next] = sff_twin_controller(t,x,mode,C)
% Experimental native controller: mode 4 adaptive event, mode 5 fault-aware self.
% Model-based windowed torque regression, no injected effectiveness input.
% Call clear sff_twin_controller before a new native run.
persistent init held bs bw uh ch tn last rate tries recv prevW tsum ns obsU obsY nobs cursor ghat se F conf dist
if isempty(init)
 init=true;held=zeros(3,4);bs=zeros(3,4);bw=zeros(3,4);
 for i=1:4,bs(:,i)=x(6*i-5:6*i-3);bw(:,i)=x(6*i-2:6*i);end
 uh=zeros(12,1);ch=C.chi0*ones(4,1);tn=zeros(4,1);last=-ones(4,1);
 rate=zeros(4,1);tries=zeros(4,1);recv=zeros(4,1);prevW=bw;tsum=zeros(3,4);ns=0;
 obsU=zeros(80,3,4);obsY=zeros(80,3,4);nobs=0;cursor=0;
 ghat=ones(3,4);se=ones(3,4);F=zeros(4,1);conf=zeros(4,1);dist=zeros(4,1);
end
A=[0 1 0 0;1 0 1 0;1 1 0 0;1 0 0 0];pin=[1 0 0 0];degree=sum(A,2)'+pin;
k1=C.gainScale*2*(C.gamma*C.beta1+C.beta2)./degree;
k2=(C.k0+1)./(degree*C.delta);
sig=zeros(3,4);om=zeros(3,4);
for i=1:4,sig(:,i)=x(6*i-5:6*i-3)+C.noise*randn(3,1);om(:,i)=x(6*i-2:6*i)+C.noise*randn(3,1);end
if t==0,prevW=om;end
if ns>=max(1,round(.05/C.Ts))
 cursor=mod(cursor,80)+1;nobs=min(80,nobs+1);dt=ns*C.Ts;
 for i=1:4
  wmid=(prevW(:,i)+om(:,i))/2;
  y=C.J(i,:)'.*(om(:,i)-prevW(:,i))/dt+cross(wmid,C.J(i,:)'.*wmid);
  avgu=tsum(:,i)/ns;obsU(cursor,:,i)=avgu';obsY(cursor,:,i)=y';
  for a=1:3
   uu=obsU(1:nobs,a,i);yy=obsY(1:nobs,a,i);xx=sum(uu.^2);
   if nobs>=10 && xx>=.0004
    ghat(a,i)=max(0,min(1,sum(uu.*yy)/xx));
    variance=max([sum((yy-ghat(a,i)*uu).^2)/max(1,nobs-1),2*(C.J(i,a)*C.noise/dt)^2,.01^2]);
    se(a,i)=sqrt(variance/xx);
   else,se(a,i)=1;end
  end
  loss=(1-ghat(:,i)).*double(se(:,i)<.25);[F(i),axis]=max(loss);
  conf(i)=max(0,min(1,(F(i)-1.96*se(axis,i))/max(F(i),eps)));
  dist(i)=norm(y-ghat(:,i).*avgu);
 end
 prevW=om;tsum=zeros(3,4);ns=0;
end
[sd,od]=sff_ref(t);sB=bs;oB=bw;trig=zeros(4,1);sout=zeros(12,1);
for i=1:4
 q=3*(i-1);e1=pin(i)*(sig(:,i)-sd);e2=pin(i)*(om(:,i)-od);
 for j=1:4,if A(i,j),e1=e1+sig(:,i)-sB(:,j);e2=e2+om(:,i)-oB(:,j);end,end
 s=e2+C.r*e1;sout(q+1:q+3)=s;err=sum((held(:,i)-s).^2);ss=sum(held(:,i).^2);
 base=C.delta*ss+ch(i)+C.epsilon;
 demand=C.errorWeight*(norm(s)+norm(e1)+norm(e2))+C.faultWeight*F(i)*conf(i)+C.disturbanceWeight*min(5,dist(i)/.01);
 resource=C.commWeight*(tries(i)/max(1,C.budget)+min(2,rate(i)/20)+C.dropout);
 scale=max(.05,min(3,(1+resource)/(1+demand)));threshold=max(1e-9,base*scale);
 if mode==5,fire=t>=tn(i)-C.Ts/2;else,fire=t==0||err>=threshold||(last(i)>=0&&t-last(i)>=C.maxInterval);end
 rate(i)=rate(i)*exp(-C.Ts);
 if fire
  phi=1+norm(om(:,i))+sum(om(:,i).^2);cmd=-k1(i)*s-k2(i)*C.alpha*phi*sign(s);
  if conf(i)>.5,cmd=cmd./max(.35,min(1,ghat(:,i)));end
  uh(q+1:q+3)=cmd;held(:,i)=s;trig(i)=1;last(i)=t;rate(i)=rate(i)+1;
  if tries(i)<C.budget
   tries(i)=tries(i)+1;
   if t<C.disturbanceTime || rand()>=C.dropout,bs(:,i)=sig(:,i);bw(:,i)=om(:,i);recv(i)=recv(i)+1;end
  end
  err=0;ss=sum(s.^2);
  if mode==5
   den=2/min(C.J(i,:))*(5*k1(i)*norm(s)+(5*k2(i)+1)*C.alpha*phi);tk=t;
   for it=1:60,tk=t+sqrt(C.delta*ss+C.chi0*exp(-(C.beta1+C.beta2)*tk)+C.epsilon)/den;end
   tn(i)=t+max(C.Ts,min(C.maxInterval,(max(t+C.Ts,tk)-t)*sqrt(scale)));
  end
 end
 if mode==5,ch(i)=C.chi0*exp(-(C.beta1+C.beta2)*t);else,ch(i)=max(0,ch(i)+C.Ts*(-C.beta1*ch(i)+C.beta2*(C.delta*ss+C.epsilon-err)));end
end
u=uh;chi=ch;severity=F;evidence=conf;attempts=tries;delivered=recv;next=tn;
for i=1:4,tsum(:,i)=tsum(:,i)+max(-.2,min(.2,u(3*i-2:3*i)));end
ns=ns+1;
end
