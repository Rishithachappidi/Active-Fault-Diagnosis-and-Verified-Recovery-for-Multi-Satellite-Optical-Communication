function tests=test_revision_v2
tests=functiontests(localfunctions);
end
function test_truth_excluded(t)
c=default_config;d=v2_nominal(c);verifyFalse(t,any(ismember(fieldnames(d),{'scenario','faultStart','faultEnd','severity','noiseSamples','initialAngle'})));
c.scenario='sensor';c.severity=999;c.faultEnd=3;verifyEqual(t,d,v2_nominal(c));
end
function test_ambiguous_dark_link(t)
c=v2_nominal(default_config);s=zeros(30,1);
o=struct('angle',[0;0],'rate',[0;0],'power',0,'command',[0;0],'delivered',[0;0],'reference',[0;0]);
[s,~,label,~,probe]=v2_decision_step(2,o,s,zeros(8,0),c);
verifyEqual(t,label,7);verifyEqual(t,probe,[0;0]);
end
function test_no_information_is_not_unique(t)
c=v2_nominal(default_config);B=zeros(8,30);B(1,:)=(0:29)*c.dt;
[label,~,~,~,~]=v2_actuator_fit(B,c);verifyEqual(t,label,7);
[ok,~,~,~,~]=v2_optical_fit(B,c);verifyFalse(t,ok);
end
function test_stale_correction_is_discarded(t)
c=v2_nominal(default_config);s=zeros(30,1);s(7)=1;s(10)=1;s(9)=2;s(11:12)=[23;10]*1e-6;s(13)=1;s(1:2)=-s(11:12);
o=struct('angle',s(1:2),'rate',[0;0],'power',optical_power(s(1:2),1,false,c),'command',[0;0],'delivered',[0;0],'reference',s(1:2));
[s,~,~,~,~]=v2_decision_step(4,o,s,zeros(8,0),c);
[s,ref,~,action,~]=v2_decision_step(4.1,o,s,zeros(8,0),c);
verifyEqual(t,s(10),0);verifyEqual(t,action,5);verifyLessThan(t,norm(ref),2e-6);
end
function test_simulink_all_sizes(t)
for n=[4 6 8 10]
 c=default_config(n);c.T=1.2;r=run_case_v2(c,[]);
 verifySize(t,r.Y,[numel(r.t) 26*c.m]);verifySize(t,r.E,[numel(r.t) 16*c.m]);
 verifyTrue(t,all(isfinite(r.Y),'all'));verifyTrue(t,all(isfinite(r.D),'all'));
end
end
function test_physical_recovery_and_clearance(t)
c=default_config;c.scenario='pointing';r=run_case_v2(c,[]);
verifyGreaterThan(t,r.metrics.isolation_accuracy,0.6);verifyEqual(t,r.metrics.recovery_success,1);
verifyEqual(t,r.extra.postclear_restoration_verified,1);verifyLessThan(t,r.extra.postclear_outage_s,1.5);
end
function test_sensor_change_uses_rate_history(t)
c=default_config;c.scenario='sensor';r=run_case_v2(c,[]);
verifyGreaterThan(t,r.metrics.isolation_accuracy,0.9);verifyLessThan(t,r.metrics.link_outage_s,0.1);verifyEqual(t,r.extra.postclear_restoration_verified,1);
end
function test_power_limited_combination_not_corrected(t)
c=default_config;c.scenario='simultaneous';r=run_case_v2(c,[]);
verifyTrue(t,any(r.D(:,1)==8));verifyEqual(t,r.metrics.recovery_success,0);verifyLessThan(t,r.extra.postclear_outage_s,0.1);
end
function test_kinematic_assumption_is_necessary(t)
% If rate is derived from the biased encoder, a jump enters both channels.
% This controlled observation-level test demonstrates the ambiguity remains.
c=v2_nominal(default_config);s=zeros(30,1);s(7)=1;
o=struct('angle',[23;0]*1e-6,'rate',[46;0]*1e-6/c.dt,'power',0,'command',[0;0],'delivered',[0;0],'reference',[0;0]);
[s,~,~,~,~]=v2_decision_step(2,o,s,zeros(8,0),c);
verifyLessThan(t,norm(s(3:4)),1e-12);
end
