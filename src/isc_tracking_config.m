function c=isc_tracking_config(mode,scenario,seed,policy)
if nargin<1,mode='optical_event';end
if nargin<2,scenario='pointing';end
if nargin<3,seed=11;end
if nargin<4,policy='off';end
allowed={'healthy','pointing','body_actuator','moderate_attenuation',...
    'pointing_actuator','pointing_attenuation','actuator_attenuation','combined','attenuation'};
assert(ismember(scenario,allowed),'Unknown tracking scenario');
c=isc_config(mode,'healthy',seed);c.scenario=scenario;
c.task='leader_tracking';c.T=75;c.gimbalTau=0.06;
c.parent=[0 1 2 3];c.activeEndpoints=[1 2 7 8 11 12];
c.offsets=zeros(4,4);angles=[0 .004 -.003 .002;0 -.002 .003 .001;0 .002 .001 -.003];
for i=1:4,c.offsets(:,i)=isc_math('exp',angles(:,i));end
c.policy=policy;
assert(ismember(policy,{'off','schedule','prediction','both','frozen'}),'Unknown management policy');
c.manageSchedule=ismember(policy,{'schedule','both'});
c.managePrediction=ismember(policy,{'prediction','both'});
if strcmp(policy,'frozen'),assert(c.event,'Frozen policy is defined for event scheduling');end
c.managedHorizon=3;c.managedGap=0.2;c.infeasibleGap=1.6;
c.blackout=false;c.referencePhase=0;
end
