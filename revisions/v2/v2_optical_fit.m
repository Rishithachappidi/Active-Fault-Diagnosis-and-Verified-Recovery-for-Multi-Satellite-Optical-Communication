function [ok,offset,gain,condition,err]=v2_optical_fit(B,c)
ok=false;offset=[0;0];gain=1;condition=0;err=Inf;
[p0,~,~]=optical_power([0;0],1,false,c);
good=B(4,:)>0.005*p0;B=B(:,good);
if size(B,2)<20,return;end
X=[ones(size(B,2),1) B(2:3,:)'/c.divergence];
z=log(B(4,:)'/p0)+2*sum(B(2:3,:).^2,1)'/c.divergence^2;
condition=rcond(X'*X);if condition<1e-4,return;end
beta=X\z;offset=-beta(2:3)*c.divergence/4;
gain=exp(beta(1)+2*sum(offset.^2)/c.divergence^2);
res=z-X*beta;err=sqrt(mean(res.^2));
covar=(sum(res.^2)/max(size(X,1)-3,1))*((X'*X)\eye(3));
offsetSE=c.divergence*sqrt(max(0,sum(diag(covar(2:3,2:3)))))/4;
ok=err<0.08 && offsetSE<2e-6 && gain>0.02 && gain<1.5 && norm(offset)<60e-6;
end
