function s=isc_init(c)
s.q=zeros(4,4); s.w=zeros(3,4);
angles=[0.012 -0.008 0.009 -0.011;-0.006 0.010 -0.008 0.007;0.008 -0.005 0.006 -0.009];
if isfield(c,'initialAngles'),angles=c.initialAngles;assert(isequal(size(angles),[3 4]));end
for i=1:4,s.q(:,i)=isc_math('exp',angles(:,i));end
if isfield(c,'initialW'),s.w=c.initialW;assert(isequal(size(s.w),[3 4]));end
s.torque=zeros(3,4); s.previousW=zeros(3,4); s.disturbance=zeros(3,4);
s.gimbal=zeros(2,c.M); s.correction=s.gimbal; s.offset=s.gimbal;
s.gain=ones(1,c.M); s.valid=zeros(1,c.M); s.mismatch=zeros(1,c.M);
s.label=zeros(1,c.M); s.hold=zeros(1,c.M);
s.hx=zeros(2,c.fitSamples,c.M); s.hp=zeros(c.fitSamples,c.M);
s.hcount=zeros(1,c.M); s.hindex=zeros(1,c.M);
s.cachedQ=repmat(reshape([1;0;0;0],4,1,1),1,4,4);
s.cachedW=zeros(3,4,4); s.stamp=-ones(4,4)*100;
s.sentQ=repmat([1;0;0;0],1,4); s.sentW=zeros(3,4);
s.lastSend=-ones(1,4)*100;
% One pending slot per directed edge. Delay < minimum periodic interval is
% not required: each edge has a bounded 32-slot queue.
s.queue=zeros(11,32,c.M); s.queueCount=zeros(1,c.M);
s.attempts=zeros(1,4); s.deliveries=zeros(1,4);
for a=1:c.M
    s.gimbal(:,a)=isc_target(s.q(:,c.sender(a)),c,a);
end
if isfield(c,'task') && strcmp(c.task,'leader_tracking')
    s.holdQ=s.q;s.lastSendEdge=-100*ones(1,c.M);
    s.sentQEdge=repmat([1;0;0;0],1,c.M);s.sentWEdge=zeros(3,c.M);
    s.rateChange=1e6*ones(4,4); % finite sentinel: not enough delivered rate history
end
end
