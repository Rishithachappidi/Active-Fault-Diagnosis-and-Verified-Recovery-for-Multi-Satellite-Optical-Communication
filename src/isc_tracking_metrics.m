function [m,trace]=isc_tracking_metrics(r,c)
K=numel(r.t);trace.commandError=zeros(K,4);trace.leaderError=zeros(K,4);
trace.pairError=zeros(K,6);trace.parentAge=zeros(K,3);
for k=1:K
    [qr,~]=isc_reference(r.t(k),c.referencePhase);
    q=zeros(4,4);common=zeros(4,4);
    for i=1:4
        q(:,i)=isc_math('exp',squeeze(r.att(k,:,i))');
        common(:,i)=isc_math('mul',q(:,i),isc_math('conj',c.offsets(:,i)));
        desired=isc_math('mul',qr,c.offsets(:,i));
        trace.commandError(k,i)=norm(isc_math('log',isc_math('mul',isc_math('conj',desired),q(:,i))));
        trace.leaderError(k,i)=norm(isc_math('log',isc_math('mul',isc_math('conj',common(:,1)),common(:,i))));
        if i>1,trace.parentAge(k,i-1)=r.age(k,c.parent(i),i);end
    end
    for e=1:6
        i=c.edges(e,1);j=c.edges(e,2);
        trace.pairError(k,e)=norm(isc_math('log',isc_math('mul',isc_math('conj',common(:,i)),common(:,j))));
    end
end
m.mode=string(c.mode);m.scenario=string(c.scenario);m.policy=string(c.policy);m.seed=c.seed;
windows={r.t>=10,r.t>=c.faultStart&r.t<c.faultEnd,r.t>=c.faultEnd};
names={'evaluation','fault','postclearance'};
for h=1:3
    idx=windows{h};prefix=names{h};
    m.([prefix '_pair_rms_rad'])=sqrt(mean(trace.pairError(idx,:).^2,'all'));
    m.([prefix '_tracking_rms_rad'])=sqrt(mean(trace.commandError(idx,:).^2,'all'));
    m.([prefix '_follower_tracking_rms_rad'])=sqrt(mean(trace.commandError(idx,2:4).^2,'all'));
    m.([prefix '_leader_relative_rms_rad'])=sqrt(mean(trace.leaderError(idx,2:4).^2,'all'));
    m.([prefix '_control_effort_N2m2s'])=sum(r.torque(idx,:,:).^2,'all')*c.dt;
    m.([prefix '_attempts'])=sum(r.attempts(idx,:),'all');
end
m.fault_pair_peak_rad=max(trace.pairError(windows{2},:),[],'all');
m.attempted_packets=sum(r.attempts,'all');m.delivered_packets=sum(r.deliveries,'all');
% Explicit serialized state payload: 4 quaternion + 3 rate + 1 timestamp
% doubles. Arrival time/routing IDs are simulator metadata, excluded here.
m.state_payload_bytes=64*m.attempted_packets;
m.control_effort_N2m2s=sum(r.torque.^2,'all')*c.dt;
m.fault_saturation_fraction=mean(abs(r.torque(windows{2},:,:))>=c.umax*(1-1e-8),'all');
m.affected_availability=r.metrics.affected_link_availability;
m.fault_window_recovered=r.metrics.fault_window_recovered;m.recovery_time_s=r.metrics.recovery_time_s;
m.parent_uninitialized_fraction=mean(trace.parentAge(windows{2},:)>=100,'all');
age=trace.parentAge(windows{2},:);age=age(age<100);
if isempty(age),m.initialized_parent_age_s=NaN;else,m.initialized_parent_age_s=mean(age);end
m.queue_overflows=r.metrics.queue_overflows;m.quaternion_norm_error=r.metrics.quaternion_norm_error;
m.degraded_policy_fraction=mean(ismember(r.manager(windows{2},c.activeEndpoints),[1 2]),'all');
m.infeasible_policy_fraction=mean(r.manager(windows{2},c.activeEndpoints)==3,'all');
valid=windows{2} & r.fitValid(:,1)>0;
m.affected_valid_fit_fraction=mean(r.fitValid(windows{2},1)>0);
if any(valid)
    delta=r.estimatedOffset(valid,:,1)-r.injectedBias(valid,:,1);
    m.conditional_offset_rms_rad=sqrt(mean(sum(delta.^2,2)));
else,m.conditional_offset_rms_rad=NaN;end
m.affected_estimated_infeasible_fraction=mean(r.feasible(windows{2},1)==0);
end
