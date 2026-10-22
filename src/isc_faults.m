function f=isc_faults(t,c)
% EXPERIMENT ONLY. Hidden injections never enter controller/diagnosis APIs.
f.eta=ones(3,4); f.bias=zeros(2,c.M); f.gain=ones(1,c.M); f.block=false(1,c.M);
if t<c.faultStart || t>=c.faultEnd,return;end
if ismember(c.scenario,{'pointing','pointing_actuator','pointing_attenuation','combined'})
    % Both terminals on undirected edge 1 (SC1--SC2) develop boresight offset.
    scale=1;if isfield(c,'pointingFaultScale'),scale=c.pointingFaultScale;end
    f.bias(:,1:2)=repmat([0.85;-0.40]*c.divergence*scale,1,2);
end
if ismember(c.scenario,{'body_actuator','pointing_actuator','actuator_attenuation','combined'}), f.eta(:,2)=[0.35;0.5;0.4]; end
if strcmp(c.scenario,'attenuation'),f.gain(1:2)=0.12;end
if strcmp(c.scenario,'blockage'),f.block(1:2)=true;end
if strcmp(c.scenario,'combined'),f.gain(1:2)=0.65;end
if ismember(c.scenario,{'moderate_attenuation','pointing_attenuation','actuator_attenuation'}),f.gain(1:2)=0.65;end
if isfield(c,'actuatorEffectiveness') && ismember(c.scenario,{'body_actuator','pointing_actuator','actuator_attenuation','combined'})
    f.eta(:,2)=c.actuatorEffectiveness;
end
if isfield(c,'attenuationGain') && ismember(c.scenario,{'attenuation','moderate_attenuation','pointing_attenuation','actuator_attenuation','combined'})
    f.gain(1:2)=c.attenuationGain;
end
end
