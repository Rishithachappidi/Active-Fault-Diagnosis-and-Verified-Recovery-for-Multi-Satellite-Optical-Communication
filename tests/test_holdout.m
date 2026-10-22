function report=test_holdout
names={};n=struct('eventMax',.8,'infeasibleGap',1.6,'staleLimit',1.5,'managedHorizon',3,'divergence',300e-6);
p=isc_frozen_policy(1,false,.1,0,2,1e-4,n);
assert(p.horizon==3 && p.retryGap==.8);
p=isc_frozen_policy(1,false,.001,0,2,1e-4,n);assert(p.horizon==1.5);
p=isc_frozen_policy(1,false,.1,0,2,1e-3,n);assert(p.horizon==1.5);
p=isc_frozen_policy(1,false,.1,0,2,1e6,n);assert(p.horizon==1.5);
p=isc_frozen_policy(1,false,.1,0,3.1,1e-4,n);assert(p.horizon==1.5);
names{end+1}='prediction requires pilot, age and delivered-rate evidence';
p=isc_frozen_policy(3,true,.1,0,2,1e-4,n);assert(p.retryGap==1.6 && p.horizon==1.5);
p=isc_frozen_policy(3,false,.1,0,2,1e-4,n);assert(p.retryGap==.8);
p=isc_frozen_policy(0,true,.8,0,2,1e-4,n);assert(p.retryGap==.8 && p.horizon==1.5);
names{end+1}='only accepted infeasibility throttles retries';
a=isc_holdout_config('combined_new','optical_event',901,'off');
b=isc_holdout_config('combined_new','optical_event',901,'frozen');
assert(isequal(a.initialAngles,b.initialAngles)&&isequal(a.initialW,b.initialW));
assert(isequal(a.disturbancePhase,b.disturbancePhase)&&a.referencePhase==b.referencePhase);
d=isc_holdout_config('combined_new','optical_event',902,'off');
assert(~isequal(a.initialAngles,d.initialAngles));
assert(~isequal(a.disturbancePhase,d.disturbancePhase));
names{end+1}='independent seeds with paired exogenous realizations';
f=isc_faults(30,a);assert(f.gain(1)==.55&&isequal(f.eta(:,2),[.25;.4;.3]));
c=isc_holdout_config('short_small','optical_event',901);none=isc_faults(30,c);assert(~any(none.bias,'all'));
f=isc_faults(32,c);assert(norm(f.bias(:,1)-.6*[.85;-.4]*c.divergence)<eps);
names{end+1}='held-out severity and windows are injected only in plant';
% Paired runs are exactly reproducible including the new frozen policy.
c=isc_holdout_config('short_small','optical_event',901,'frozen');c.T=44;
r=isc_run(c);r2=isc_run(c);assert(isequaln(r.trackingMetrics,r2.trackingMetrics));
assert(all(isfinite(r.att),'all')&&r.metrics.quaternion_norm_error<1e-12);
assert(all(abs(r.torque)<=c.umax+eps,'all')&&r.metrics.queue_overflows==0);
names{end+1}='frozen policy reproducibility and physical bounds';
report.passed=numel(names);report.tests=names;disp(report);
end
