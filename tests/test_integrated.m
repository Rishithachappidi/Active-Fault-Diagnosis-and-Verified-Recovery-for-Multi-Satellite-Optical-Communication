function report=test_integrated
report=struct;names={};
% Quaternion composition and fixed-geometry LOS transform.
q=isc_math('exp',[.1;-.2;.3]);R=isc_math('rot',q);
assert(norm(R'*R-eye(3),'fro')<1e-12);assert(abs(det(R)-1)<1e-12);
assert(norm(isc_math('log',q)-[.1;-.2;.3])<1e-12);names{end+1}='quaternion geometry';
% Optical fitting must identify known offset AND attenuation from observations.
c=isc_config; n=struct('samples',c.fitSamples,'divergence',c.divergence,...
    'maxCorrection',c.maxCorrection,'threshold',.2);
s=isc_init(c);d=struct('hindex',0,'hx',s.hx(:,:,1),'hp',s.hp(:,1)',...
    'hcount',0,'correction',[0;0],'offset',[0;0],'gain',1,'valid',0,'mismatch',0,'label',0);
offset=[.7;-.3]*c.divergence;gain=.6;
for k=1:100
    x=c.divergence*.25*[sin(k*.31);cos(k*.23)];
    o=struct('x',x,'power',gain*exp(-2*sum((x+offset).^2)/c.divergence^2),'decision',true);
    [d,cor]=isc_diagnose(o,d,n);
end
assert(d.valid && norm(d.offset-offset)<1e-10 && abs(d.gain-gain)<1e-8);
assert(norm(cor+offset)<1e-10);names{end+1}='observable optical parameter recovery';
% Regression: invalidation must clear both count and ring position, otherwise
% a short new history can accidentally fit stale pre-fault buffer slots.
d.valid=1;d.offset=[0;0];d.gain=1;d.mismatch=0;
d.hindex=17;d.hcount=n.samples;d.hx(:)=9*c.divergence;d.hp(:)=1;
o=struct('x',[0;0],'power',0,'decision',true);
for k=1:3,[d,~]=isc_diagnose(o,d,n);end
assert(d.hcount==0 && d.hindex==0 && ~d.valid);
assert(~any(d.hx,'all') && ~any(d.hp,'all'));
o.x=[1;2]*1e-6;o.decision=false;[d,~]=isc_diagnose(o,d,n);
assert(d.hcount==1 && d.hindex==1 && isequal(d.hx(:,1),o.x));
names{end+1}='no stale samples after fit invalidation';
% Dark observations cannot prove blockage or invent a usable optical fit.
d.valid=0;d.hcount=0;d.offset=[0;0];d.correction=[0;0];
for k=1:80,o.power=0;[d,cor]=isc_diagnose(o,d,n);end
assert(d.label==3 && ~d.valid && norm(cor)==0);names{end+1}='darkness remains ambiguous';
% Packet causality: no injected neighbor state before a successful delivery.
c=isc_config('optical_event','healthy',11);s=isc_init(c);rng(c.seed);
[s,z]=isc_step(s,0,1,c);assert(all(s.stamp(~eye(4))<0));
assert(sum(z.deliveries)==0);names{end+1}='no instantaneous neighbor truth';
% The receiver uses stamped immutable payloads; subsequent plant states
% cannot alter queued messages.
packet=s.queue(:,1,1);s.q(:,1)=isc_math('exp',[.5;0;0]);
assert(isequal(packet,s.queue(:,1,1)));names{end+1}='immutable packet payload';
% State serialization is exact, including all queue/history dimensions.
packed=isc_pack(s);again=isc_pack(packed,isc_init(c));assert(isequaln(s,again));names{end+1}='Simulink state serialization';
% Matched-seed repeatability, physical bounds, and real event savings.
c=isc_config('optical_event','pointing',11);c.T=35;
r=isc_run(c);r2=isc_run(c);assert(isequaln(r.att,r2.att)&&isequal(r.power,r2.power));
assert(all(isfinite(r.att),'all') && all(abs(r.torque)<=c.umax+eps,'all'));
assert(r.metrics.quaternion_norm_error<1e-12 && r.metrics.queue_overflows==0);
names{end+1}='repeatability and physical bounds';
c.mode='optical_periodic';c.event=false;rp=isc_run(c);
assert(r.metrics.attempted_packets<rp.metrics.attempted_packets);names{end+1}='event scheduler reduces attempts';
% Real feedback coupling: broken optical sessions remove message delivery.
c=isc_config('optical_periodic','blockage',11);c.T=35;r=isc_run(c);
assert(~any(r.up(r.t>=25,1:2),'all'));names{end+1}='blockage interrupts state transport';
% Compensation must improve physical availability for a persistent offset.
c=isc_config('optical_event','pointing',11);c.T=45;r=isc_run(c);
c.recovery=false;baseline=isc_run(c);
idx=r.t>=32;
assert(mean(r.up(idx,1:2),'all')>mean(baseline.up(idx,1:2),'all')+.2);
names{end+1}='pointing correction restores physical links';
report.passed=numel(names);report.tests=names;report.matlab=version;
disp(report);fprintf('Passed %d integrated checks.\n',numel(names));
end
