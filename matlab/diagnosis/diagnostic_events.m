function events=diagnostic_events(r)
c=r.config;dc=diagnostic_config(c);events=struct([]);
for j=1:c.m
 di=(j-1)*8;yi=(j-1)*26;
 changes=find([true;diff(r.D(:,di+1))~=0 | diff(r.D(:,di+3))~=0]);
 for k=changes'
  o=sensor_view(r.Y(k,yi+(1:26))');d=passive_diagnosis(o,[],dc);
  label=r.D(k,di+1);action=r.D(k,di+3);
  if label==4,d.alternatives=4;d.evidence='active angle/power fit consistent with scalar loss';end
  if label==7 && action==3,d.alternatives=[1 6 8];d.evidence='active optical gradient; boresight and sensor bias unresolved';end
  e=struct('time_s',r.t(k),'edge',j,'hypothesis_code',label,'alternatives',d.alternatives,...
   'confidence',NaN,'uncertain',label==7,'evidence',d.evidence,'recovery_action',action);
  if isempty(events),events=e;else,events(end+1)=e;end
 end
end
end

