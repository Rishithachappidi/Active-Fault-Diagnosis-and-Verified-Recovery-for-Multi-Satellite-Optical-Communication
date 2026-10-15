function m=compute_metrics(r)
c=r.config;t=r.t;Y=r.Y;D=r.D;idx=t>=c.warmup & t<c.T;
truth=D(:,4);pred=D(:,1);actual=truth~=0;det=pred~=0;
tp=sum(actual(idx)&det(idx));tn=sum(~actual(idx)&~det(idx));fp=sum(~actual(idx)&det(idx));fn=sum(actual(idx)&~det(idx));
m.detection_accuracy=(tp+tn)/sum(idx);m.precision=divide(tp,tp+fp);m.recall=divide(tp,tp+fn);m.false_positive_rate=divide(fp,fp+tn);m.false_negative_rate=divide(fn,fn+tp);
m.isolation_accuracy=divide(sum(pred(idx&actual)==truth(idx&actual)),sum(idx&actual));m.uncertain_frequency=mean(pred(idx)==7);
m.diagnosis_time_s=NaN;k=find(t>=c.faultStart & actual & det,1);if ~isempty(k),m.diagnosis_time_s=t(k)-c.faultStart;end
err=Y(idx,5:6);m.rms_pointing_rad=sqrt(mean(sum(err.^2,2)));m.max_pointing_rad=max(vecnorm(err,2,2));
m.control_effort_Nm2s=sum(sum(Y(idx,11:12).^2))*c.dt;m.control_total_variation_Nm=sum(abs(diff(Y(idx,11:12))), 'all');
m.saturation_s=sum(Y(idx,15))*c.dt;m.command_delivery_rms_Nm=sqrt(mean((Y(idx,11:12)-Y(idx,13:14)).^2,'all'));
m.settling_time_s=NaN;ii=find(t>=c.faultStart & t<c.faultEnd);good=vecnorm(Y(:,5:6),2,2)<2e-6;
for k=ii',if all(good(k:ii(end))),m.settling_time_s=t(k)-c.faultStart;break;end,end
m.link_availability=mean(Y(idx,18:26:end),'all');m.affected_link_availability=mean(Y(idx,18));
m.link_outage_s=sum(Y(idx,18)<0.5)*c.dt;
g=8*c.m;m.network_outage_s=sum(D(idx,g+1)==0)*c.dt;m.packet_delivery_ratio=mean(D(idx,g+3));m.throughput_bps=mean(D(idx,g+1));
lat=D(idx,g+2);m.latency_s=mean(lat(lat>=0));m.runtime_s=r.runtime;
m.link_recovery_time_s=NaN;m.recovery_success=NaN;
faultwin=t>=c.faultStart & t<c.faultEnd;
first=find(faultwin & Y(:,18)<0.5,1);
if ~isempty(first)
 m.recovery_success=0;holdN=round(0.5/c.dt);
 for k=first+1:numel(t)-holdN
  if t(k+holdN)>=c.faultEnd,break;end
  if all(Y(k:k+holdN,18)>0.5),m.link_recovery_time_s=t(k)-t(first);m.recovery_success=1;break;end
 end
end
attempt=D(:,3)==3 & [true;diff(D(:,3))~=0];m.unnecessary_recovery_attempts=sum(attempt & ~actual);
m.active_probe_s=sum(D(idx,7))*c.dt;
m.confusion=zeros(9);for k=find(idx)',m.confusion(truth(k)+1,pred(k)+1)=m.confusion(truth(k)+1,pred(k)+1)+1;end
end
function x=divide(a,b)
if b==0,x=NaN;else,x=a/b;end
end

