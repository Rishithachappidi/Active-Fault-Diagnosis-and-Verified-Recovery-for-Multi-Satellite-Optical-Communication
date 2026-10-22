function [s,attempts]=isc_tracking_schedule(s,t,c,manager,dropDraw,delayDraw,up,retryGap)
attempts=zeros(1,4);
for a=c.activeEndpoints
    i=c.sender(a);elapsed=t-s.lastSendEdge(a);gap=c.eventMax;
    if c.manageSchedule
        if ismember(manager(a),[1 2]),gap=c.managedGap;
        elseif manager(a)==3,gap=c.infeasibleGap;end
    end
    if strcmp(c.policy,'frozen'),gap=retryGap(a);end
    send=elapsed>=c.period-1e-10;
    if c.event
        represented=isc_math('mul',s.sentQEdge(:,a),isc_math('exp',s.sentWEdge(:,a)*min(elapsed,gap)));
        innovation=norm(isc_math('log',isc_math('mul',isc_math('conj',represented),s.q(:,i))));
        send=elapsed>=c.eventMin-1e-10 && (innovation>c.eventAngle ||...
            norm(s.w(:,i)-s.sentWEdge(:,a))>c.eventRate || elapsed>=gap-1e-10);
        % Estimated infeasibility throttles retries even if local motion is
        % changing. It never prevents local pilot diagnosis from continuing.
        if c.manageSchedule && manager(a)==3,send=elapsed>=gap-1e-10;end
        if strcmp(c.policy,'frozen') && gap>c.eventMax,send=elapsed>=gap-1e-10;end
    end
    if ~send,continue;end
    s.lastSendEdge(a)=t;s.sentQEdge(:,a)=s.q(:,i);s.sentWEdge(:,a)=s.w(:,i);
    attempts(i)=attempts(i)+1;
    if ~up(a) || (~c.ideal && dropDraw(a)<c.randomDrop),continue;end
    count=s.queueCount(a)+1;assert(count<=size(s.queue,2),'Tracking queue overflow');
    delay=c.delay+c.jitter*delayDraw(a);if c.ideal,delay=0;end
    arrival=t+max(c.dt,ceil(delay/c.dt)*c.dt);
    s.queue(:,count,a)=[arrival;t;s.q(:,i);s.w(:,i);i;c.receiver(a)];
    s.queueCount(a)=count;
end
end
