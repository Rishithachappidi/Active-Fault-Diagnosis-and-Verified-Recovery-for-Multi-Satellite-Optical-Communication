function m=isc_metrics(r,c)
% All denominators and evaluation windows are explicit; repeated time samples
% are not claimed to be independent trials.
eval=r.t>=10;fault=r.t>=c.faultStart&r.t<c.faultEnd;
late=r.t>=c.T-10;
angle=squeeze(sqrt(sum(r.att.^2,2)));
m.mode=string(c.mode);m.scenario=string(c.scenario);m.seed=c.seed;
m.attitude_rms_rad=sqrt(mean(angle(eval,:).^2,'all'));
m.final_rms_rad=sqrt(mean(angle(late,:).^2,'all'));
m.fault_peak_rad=max(angle(fault,:),[],'all');
m.link_availability=mean(r.up(eval,:),'all');
m.affected_link_availability=mean(r.up(fault,1:2),'all');
m.attempted_packets=sum(r.attempts,'all');m.delivered_packets=sum(r.deliveries,'all');
m.packet_delivery_ratio=m.delivered_packets/max(1,m.attempted_packets);
m.control_energy_N2m2s=sum(r.torque.^2,'all')*c.dt;
m.saturation_fraction=mean(abs(r.torque)>=c.umax*(1-1e-8),'all');
mask=repmat(~eye(4),1,1,sum(eval));age=permute(r.age(eval,:,:),[2 3 1]);
ages=age(mask & age<100);if isempty(ages),m.mean_information_age_s=NaN;else,m.mean_information_age_s=mean(ages);end
m.queue_overflows=sum(r.overflow);m.quaternion_norm_error=max(abs(r.qnorm-1),[],'all');
% Sustained recovery of the specifically faulted physical link while fault
% remains active. A healthy sample at fault onset is not a recovery event.
affected=all(r.up(:,1:2),2);idx=find(fault);firstDown=find(~affected(idx),1);
m.recovery_time_s=NaN;m.fault_window_recovered=NaN;
if ~isempty(firstDown)
    m.fault_window_recovered=0;count=0;
    for h=firstDown:numel(idx)
        if affected(idx(h)),count=count+1;else,count=0;end
        if count>=round(1/c.dt)
            m.recovery_time_s=r.t(idx(h))-r.t(idx(firstDown));
            m.fault_window_recovered=1;break;
        end
    end
end
m.evaluated_link_samples=sum(eval)*c.M;
m.fault_affected_link_samples=sum(fault)*2;
end
