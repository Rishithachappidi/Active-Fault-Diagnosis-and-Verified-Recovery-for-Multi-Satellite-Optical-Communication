function report=test_tracking
c=isc_tracking_config; s=isc_init(c);names={};
n=struct('parent',c.parent,'offsets',c.offsets,'holdQ',s.holdQ,...
    'predictionHorizon',1.5*ones(1,4),'predict',true,'referencePhase',0);
[a,wa]=isc_tracking_target(2,s.cachedQ,s.cachedW,s.stamp,30,n);
n.referencePhase=1;[b,wb]=isc_tracking_target(2,s.cachedQ,s.cachedW,s.stamp,30,n);
assert(isequal(a,b)&&isequal(wa,wb));
[leader,~]=isc_tracking_target(1,s.cachedQ,s.cachedW,s.stamp,30,n);
n.referencePhase=0;[leader2,~]=isc_tracking_target(1,s.cachedQ,s.cachedW,s.stamp,30,n);
assert(norm(leader-leader2)>1e-3);names{end+1}='only leader reads external command';
% Construct an exact commanded formation and check parent-to-child offsets.
[qr,~]=isc_reference(30);s.cachedQ(:,1,2)=isc_math('mul',qr,c.offsets(:,1));s.stamp(1,2)=30;
[qd,~]=isc_tracking_target(2,s.cachedQ,s.cachedW,s.stamp,30,n);
desired=isc_math('mul',qr,c.offsets(:,2));assert(norm(qd-desired)<1e-12);
names{end+1}='relative-attitude target transfer';
s.cachedW(:,1,2)=[.01;0;0];[qold,wold]=isc_tracking_target(2,s.cachedQ,s.cachedW,s.stamp,40,n);
[qolder,~]=isc_tracking_target(2,s.cachedQ,s.cachedW,s.stamp,45,n);
assert(norm(qold-qolder)<1e-12&&norm(wold)==0);names{end+1}='stale target freezes after bounded prediction';
limits=struct('divergence',c.divergence,'maxCorrection',c.maxCorrection,'threshold',c.sensitivity);
m=isc_link_management(.1e-6,[.2e-3;0],1,true,1e-6,limits);
assert(m.state==2&&m.feasible==1);
m=isc_link_management(.1e-6,[0;0],.12,true,1e-6,limits);
assert(m.state==3&&m.feasible==0);
m=isc_link_management(0,[0;0],1,false,1e-6,limits);
assert(m.state==1&&m.feasible==-1);names{end+1}='observable feasibility distinguishes uncertainty';
% Identical component magnitudes are mandatory for factorial interactions.
for scenario={'pointing','pointing_actuator','pointing_attenuation','combined'}
    c2=isc_tracking_config('optical_event',scenario{1},11);f=isc_faults(30,c2);
    assert(norm(f.bias(:,1)-[.85;-.4]*c.divergence)<eps);
end
for scenario={'moderate_attenuation','pointing_attenuation','actuator_attenuation','combined'}
    c2=isc_tracking_config('optical_event',scenario{1},11);f=isc_faults(30,c2);assert(f.gain(1)==.65);
end
names{end+1}='factorial component magnitudes match';
% The complete nonlinear task must remain reproducible and bounded.
c=isc_tracking_config('optical_event','pointing',11);c.T=32;
r=isc_run(c);r2=isc_run(c);
assert(isequaln(r.trackingMetrics,r2.trackingMetrics));
assert(all(isfinite(r.att),'all')&&max(abs(r.torque),[],'all')<=c.umax+eps);
assert(r.metrics.queue_overflows==0&&r.metrics.quaternion_norm_error<1e-12);
names{end+1}='tracking repeatability and physical bounds';
% Strong end-to-end access test: with every packet blocked, changing only
% the external leader command must not change any follower trajectory.
c=isc_tracking_config('ideal_periodic','healthy',11);c.T=32;c.blackout=true;
ra=isc_run(c);c.referencePhase=1;rb=isc_run(c);
assert(isequal(ra.att(:,:,2:4),rb.att(:,:,2:4)));
assert(~isequal(ra.att(:,:,1),rb.att(:,:,1)));
assert(sum(ra.deliveries,'all')==0);names{end+1}='blackout prevents hidden reference access end to end';
report.passed=numel(names);report.tests=names;disp(report);
end
