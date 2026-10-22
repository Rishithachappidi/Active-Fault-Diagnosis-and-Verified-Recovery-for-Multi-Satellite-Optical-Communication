function detail=summarize_fault_windows
% Postprocess saved first-seed logs to separate the fault response from the
% much larger initial attitude maneuver. No new simulation is performed.
root=fileparts(mfilename('fullpath'));
files=dir(fullfile(root,'results','*__*.mat'));parts=cell(numel(files),1);
for k=1:numel(files)
    data=load(fullfile(files(k).folder,files(k).name),'r','c');r=data.r;c=data.c;
    fault=r.t>=c.faultStart&r.t<c.faultEnd;
    tail=r.t>=c.faultStart+5&r.t<c.faultEnd;
    angle=squeeze(sqrt(sum(r.att.^2,2)));
    row.mode=string(c.mode);row.scenario=string(c.scenario);row.seed=c.seed;
    row.fault_rms_rad=sqrt(mean(angle(fault,:).^2,'all'));
    row.fault_after_5s_rms_rad=sqrt(mean(angle(tail,:).^2,'all'));
    row.SC2_fault_peak_rad=max(angle(fault,2));
    % Relative attitude disagreement, rather than absolute reference error.
    difference=r.att(:,:,c.edges(:,1))-r.att(:,:,c.edges(:,2));
    row.small_angle_pairwise_rms_rad=sqrt(mean(sum(difference(fault,:,:).^2,2),'all'));
    parts{k}=struct2table(row);
end
detail=vertcat(parts{:});
writetable(detail,fullfile(root,'results','first_seed_fault_windows.csv'));
end
