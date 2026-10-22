function contrasts=isc_tracking_interactions(main,out)
% Paired-seed contrasts with consistent P/A/T component magnitudes.
modes=unique(main.mode,'stable');seeds=unique(main.seed,'stable');parts={};
metrics={'fault_pair_rms_rad','fault_tracking_rms_rad','fault_control_effort_N2m2s','attempted_packets'};
for a=1:numel(modes)
    for b=1:numel(seeds)
        group=main(main.mode==modes(a)&main.seed==seeds(b)&main.policy=="off",:);
        for h=1:numel(metrics)
            field=metrics{h};v=@(s)group.(field)(group.scenario==string(s));
            row.mode=modes(a);row.seed=seeds(b);row.metric=string(field);
            row.PxA=v('pointing_actuator')-v('pointing')-v('body_actuator')+v('healthy');
            row.PxAxT=v('combined')-v('pointing_actuator')-v('pointing_attenuation')-v('actuator_attenuation')...
                +v('pointing')+v('body_actuator')+v('moderate_attenuation')-v('healthy');
            parts{end+1,1}=struct2table(row); %#ok<AGROW>
        end
    end
end
contrasts=vertcat(parts{:});
ideal=contrasts.mode=="ideal_periodic";
assert(all(abs(contrasts.PxA(ideal))<1e-12)&all(abs(contrasts.PxAxT(ideal))<1e-12),...
    'Optical fault unexpectedly changes ideal-channel dynamics');
if nargin>1,writetable(contrasts,fullfile(out,'interactions.csv'));end
end
