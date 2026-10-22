function [u,dhat,age]=isc_controller(q,w,cache,rate,stamp,oldD,previousW,previousU,t,n)
% Distributed feedback uses own sensors and RECEIVED neighbor states only.
% Smooth sliding feedback + bounded disturbance observer (not fault labels).
u=zeros(3,4); dhat=oldD; age=zeros(4,4);
for i=1:4
    qi=q(:,i); R=isc_math('rot',qi); ei=isc_math('log',qi);
    coupling=zeros(3,1);
    tracking=isfield(n,'task') && strcmp(n.task,'leader_tracking');
    rateError=w(:,i);
    if tracking
        [qd,wd,~]=isc_tracking_target(i,cache,rate,stamp,t,n);
        Rd=isc_math('rot',qd);
        ei=R'*Rd*isc_math('log',isc_math('mul',isc_math('conj',qd),qi));
        rateError=w(:,i)-R'*Rd*wd;
    end
    for j=1:4
        if i==j,continue;end
        a=max(0,t-stamp(j,i)); age(j,i)=a;
        if tracking,continue;end
        if stamp(j,i)<0,continue;end % no prior neighbor truth at startup
        qj=cache(:,j,i);
        if n.predict
            % Constant-rate propagation is deliberately bounded in time.
            qj=isc_math('mul',qj,isc_math('exp',rate(:,j,i)*min(a,n.staleLimit)));
        end
        rel=isc_math('mul',isc_math('conj',qj),qi);
        % Relative log is expressed in j body axes; transform into i axes.
        Rj=isc_math('rot',qj);
        weight=exp(-max(0,a-n.staleLimit)/n.staleLimit);
        coupling=coupling+weight*R'*Rj*isc_math('log',rel);
    end
    if t>0
        residual=n.J*(w(:,i)-previousW(:,i))/n.dt+cross(w(:,i),n.J*w(:,i))-previousU(:,i);
        dhat(:,i)=oldD(:,i)+n.observerGain*n.dt*(residual-oldD(:,i));
        dhat(:,i)=min(max(dhat(:,i),-0.6*n.umax),0.6*n.umax);
    end
    surface=rateError+n.surfaceGain*ei;
    command=-n.kp*(ei+n.coupling*coupling)-n.kd*rateError...
        -n.smc*tanh(surface/n.boundary)-dhat(:,i)+cross(w(:,i),n.J*w(:,i));
    u(:,i)=min(max(command,-n.umax),n.umax);
end
end
