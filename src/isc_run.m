function r=isc_run(c)
rng(c.seed,'twister');s=isc_init(c);r.t=(0:c.dt:c.T-c.dt)';K=numel(r.t);
r.att=zeros(K,3,4);r.rate=r.att;r.torque=r.att;
r.power=zeros(K,c.M);r.up=false(K,c.M);r.label=zeros(K,c.M);
r.correction=zeros(K,2,c.M);r.age=zeros(K,4,4);
r.attempts=zeros(K,4);r.deliveries=zeros(K,4);
r.qnorm=zeros(K,4);r.residual=zeros(K,2,c.M);r.overflow=zeros(K,1);
r.gimbal=zeros(K,2,c.M);r.injectedBias=r.gimbal;r.estimatedOffset=r.gimbal;
r.opticalGain=zeros(K,c.M);r.blocked=zeros(K,c.M);r.fitValid=zeros(K,c.M);
r.observedPower=zeros(K,c.M);
tracking=isfield(c,'task') && strcmp(c.task,'leader_tracking');
if tracking
    r.manager=zeros(K,c.M);r.severity=r.manager;r.feasible=r.manager;
    r.bestPower=r.manager;r.predictionHorizon=zeros(K,4);
end
for k=1:K
    [s,z]=isc_step(s,r.t(k),k,c);
    fields=fieldnames(z);
    for h=1:numel(fields)
        name=fields{h};value=z.(name);
        if ismatrix(value)&&size(value,1)>1
            r.(name)(k,:,:)=reshape(value,1,size(value,1),size(value,2));
        else,r.(name)(k,:)=value;end
    end
end
r.metrics=isc_metrics(r,c);r.finalState=s;
if tracking
    [r.trackingMetrics,r.tracking]=isc_tracking_metrics(r,c);
end
end
