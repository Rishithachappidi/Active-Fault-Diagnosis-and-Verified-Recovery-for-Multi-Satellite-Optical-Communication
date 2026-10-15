function x=v2_extra_metrics(r)
% Supplementary metrics: NEVER replaces or changes compute_metrics.
c=r.config;t=r.t;idx=t>=c.warmup & t<c.T;truth=r.D(:,4);pred=r.D(:,1);
x.tp=sum(idx & truth~=0 & pred~=0);x.tn=sum(idx & truth==0 & pred==0);
x.fp=sum(idx & truth==0 & pred~=0);x.fn=sum(idx & truth~=0 & pred==0);
x.fault_samples=sum(idx & truth~=0);x.total_samples=sum(idx);
x.exact_correct=sum(idx & truth~=0 & pred==truth);x.uncertain_samples=sum(idx & pred==7);
x.multiclass_accuracy=mean(pred(idx)==truth(idx));
post=t>=c.faultEnd & t<c.T;holdN=round(0.5/c.dt);
x.postclear_outage_s=sum(post & r.Y(:,18)<0.5)*c.dt;
x.postclear_false_alarm_rate=safe(sum(post & pred~=0),sum(post));
x.postclear_restoration_s=NaN;x.postclear_restoration_verified=NaN;
if ~strcmp(c.scenario,'normal') && any(post)
 x.postclear_restoration_verified=0;
 for k=find(post)'
  if k+holdN>numel(t) || t(k+holdN)>=c.T,break;end
  if all(r.Y(k:k+holdN,18)>0.5)
   x.postclear_restoration_s=t(k)-c.faultEnd;x.postclear_restoration_verified=1;break;
  end
 end
end
end
function x=safe(a,b)
if b==0,x=NaN;else,x=a/b;end
end
