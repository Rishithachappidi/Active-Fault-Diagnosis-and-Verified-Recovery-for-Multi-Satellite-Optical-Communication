function d=passive_diagnosis(o,prev,c)
% No scenario, injection schedule, hidden state or fault label is accepted.
[p0,~,~]=optical_power([0;0],1,false,c);
d=struct('label',0,'alternatives',[],'confidence',NaN,'evidence','nominal residuals','uncertain',false);
ratio=o.power/p0; nominal=p0*exp(-2*sum(o.angle.^2)/c.divergence^2);
res=abs(o.power-nominal)/p0;
if ratio<c.detectRatio || res>0.3
 d.label=7;d.alternatives=[1 4 5 6 8];d.uncertain=true;d.evidence='power residual; pointing/sensor/power ambiguity';
end
if strcmp(c.method,'threshold'),return;end
if ~isempty(prev)
 adot=(o.delivered-prev.delivered)/c.decisionPeriod;
 residual=norm(c.tau*adot+o.delivered-o.command);
 if residual>0.12*c.umax && norm(o.command)>0.15*c.umax
  d.label=7;d.alternatives=[2 3];d.uncertain=true;d.evidence='actuator dynamic residual; gain/lag unresolved';
 end
end
end

