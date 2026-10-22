function trials=audit_recovery(seeds)
% Targeted falsification of optical recovery, not a tuning/optimization sweep.
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'src'));
if nargin<1,seeds=[11 23 47];end
cases={'nominal','recovery_off','no_probe','limited_correction',...
    'slow_terminal','power_noise_5pct','beam_calibration_error',...
    'double_pointing_fault','severe_attenuation','blockage'};
out=fullfile(root,'results','recovery_audit');if ~exist(out,'dir'),mkdir(out);end
parts=cell(numel(cases)*numel(seeds),1);h=0;
for a=1:numel(cases)
    for seed=seeds
        c=isc_config('optical_event','pointing',seed);c.T=75;
        switch cases{a}
            case 'recovery_off',c.recovery=false;
            case 'no_probe',c.probeAmplitude=0;
            case 'limited_correction',c.maxCorrection=10e-6;
            case 'slow_terminal',c.gimbalTau=0.8;
            case 'power_noise_5pct',c.powerNoise=0.05;
            case 'beam_calibration_error',c.plantDivergenceScale=0.85;
            case 'double_pointing_fault',c.pointingFaultScale=2;
            case 'severe_attenuation',c.scenario='attenuation';
            case 'blockage',c.scenario='blockage';
        end
        r=isc_run(c);row=r.metrics;row.audit_case=string(cases{a});
        fault=r.t>=c.faultStart&r.t<c.faultEnd;
        i=find(r.t>=c.faultStart,1);
        row.first_command_change_s=first_time(r.t,...
            vecnorm(squeeze(r.correction(:,:,1))-squeeze(r.correction(i-1,:,1)),2,2)>50e-6,fault);
        row.first_outage_s=first_time(r.t,~r.up(:,1),fault);
        row.first_valid_fit_s=first_time(r.t,r.fitValid(:,1)>0 &...
            vecnorm(squeeze(r.estimatedOffset(:,:,1)),2,2)>0.2*c.divergence,fault);
        % Independent power recomputation reconstructs LOS from logged body
        % attitude and encoder angles, not from the existing residual output.
        predicted=zeros(size(r.power));alpha=c.divergence*c.plantDivergenceScale;
        for k=1:numel(r.t)
            for endpoint=1:c.M
                q=isc_math('exp',squeeze(r.att(k,:,c.sender(endpoint)))');
                target=isc_target(q,c,endpoint);
                residual=squeeze(r.gimbal(k,:,endpoint))'-target;
                misalignment=residual+squeeze(r.injectedBias(k,:,endpoint))';
                distance=norm(c.positions(:,c.sender(endpoint))-c.positions(:,c.receiver(endpoint)));
                p0=c.P0*(1000/distance)^2;
                predicted(k,endpoint)=p0*r.opticalGain(k,endpoint)*...
                    exp(-2*sum(misalignment.^2)/alpha^2)*(1-r.blocked(k,endpoint));
            end
        end
        row.power_recompute_max_error_W=max(abs(predicted-r.power),[],'all');
        expected=predicted>=c.sensitivity;
        for e=1:6,expected(:,2*e-1:2*e)=repmat(all(expected(:,2*e-1:2*e),2),1,2);end
        row.session_rule_disagreements=sum(expected~=r.up,'all');
        row.maximum_correction_rad=max(vecnorm(permute(r.correction,[2 1 3]),2,1),[],'all');
        assert(row.power_recompute_max_error_W<1e-15);
        assert(row.session_rule_disagreements==0);
        assert(row.maximum_correction_rad<=c.maxCorrection+1e-12);
        h=h+1;parts{h}=struct2table(row);
        if seed==seeds(1)
            save(fullfile(out,[cases{a} '.mat']),'r','c','-v7');
            if strcmp(cases{a},'nominal'),plot_audit(r,c,out);end
        end
        fprintf('AUDIT %d/%d %s seed=%d availability=%.4f verified=%g\n',...
            h,numel(parts),cases{a},seed,row.affected_link_availability,row.fault_window_recovered);
    end
end
trials=vertcat(parts{:});writetable(trials,fullfile(out,'trials.csv'));
% Controls must be able to falsify a broad claim of automatic recovery.
nominal=trials.audit_case=="nominal";off=trials.audit_case=="recovery_off";
assert(all(trials.fault_window_recovered(nominal)==1));
assert(all(trials.fault_window_recovered(off)==0));
for name=["double_pointing_fault","severe_attenuation","blockage"]
    assert(all(trials.fault_window_recovered(trials.audit_case==name)==0));
end
save(fullfile(out,'audit_tables.mat'),'trials');disp('RECOVERY_AUDIT_PASS');
end
function t=first_time(times,condition,window)
i=find(condition & window,1);if isempty(i),t=NaN;else,t=times(i);end
end
function plot_audit(r,c,out)
f=figure('Visible','off','Color','w','Position',[100 100 1300 850]);
tiledlayout(3,2,'Padding','compact','TileSpacing','compact');
nexttile;plot(r.t,squeeze(r.injectedBias(:,:,1))*1e6);ylabel('Injected offset (microrad)');legend('x truth','y truth');
nexttile;plot(r.t,squeeze(r.correction(:,:,1))*1e6);ylabel('New correction command (microrad)');legend('x command','y command');
nexttile;plot(r.t,squeeze(r.residual(:,:,1))*1e6);ylabel('Actual encoder residual (microrad)');legend('x actual','y actual');
nexttile;plot(r.t,r.power(:,1:2)*1e6);hold on;yline(c.sensitivity*1e6,'--','HandleVisibility','off');ylabel('Endpoint power (microW)');legend('SC1 end','SC2 end');
nexttile;stairs(r.t,r.up(:,1));hold on;stairs(r.t,r.fitValid(:,1));ylim([-.1 1.1]);ylabel('Session / estimator state');legend('raw session up','fit accepted');
nexttile;plot(r.t,(squeeze(r.residual(:,:,1))+squeeze(r.injectedBias(:,:,1)))*1e6);ylabel('True residual + offset (microrad)');legend('x effective','y effective');
for ax=findall(f,'Type','axes')'
    xlim(ax,[24 32]);grid(ax,'on');xlabel(ax,'Time (s)');
    xline(ax,c.faultStart,':','HandleVisibility','off');
end
exportgraphics(f,fullfile(out,'onset_timing.png'),'Resolution',150);close(f);
end
