function trials=run_holdout_experiments(caseIndices)
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'src'));
out=fullfile(root,'results','holdout');if ~exist(out,'dir'),mkdir(out);end
assert(isfile(fullfile(out,'lock.json')),'Freeze the protocol/source manifest before running held-out seeds');
cases={'principal_pointing','principal_combined','short_small','long_large',...
    'combined_new','severe_attenuation_new','beam_mismatch_new','alternate_tree_network'};
seeds=101:120;parts={};h=0;
if nargin<1,caseIndices=1:numel(cases);end
assert(all(ismember(caseIndices,1:8))&&numel(unique(caseIndices))==numel(caseIndices));
tag=strjoin(string(caseIndices),'_');
planned=sum(40+60*(caseIndices<=2));
for a=caseIndices
    if a<=2
        modes={'ideal_periodic','optical_periodic_no_recovery','optical_periodic','optical_event','optical_event'};
        policies={'off','off','off','off','frozen'};
    else,modes={'optical_event','optical_event'};policies={'off','frozen'};end
    for b=1:numel(modes)
        for seed=seeds
            c=isc_holdout_config(cases{a},modes{b},seed,policies{b});r=isc_run(c);
            row=struct2table(r.trackingMetrics);row.case_name=string(cases{a});
            row.fault_start_s=c.faultStart;row.fault_end_s=c.faultEnd;
            row.reference_phase_rad=c.referencePhase;
            parts{end+1,1}=row;h=h+1; %#ok<AGROW>
            if seed==seeds(1)
                filename=[cases{a} '__' modes{b} '__' policies{b}];
                save(fullfile(out,[filename '.mat']),'r','c','-v7');
            end
            fprintf('HOLDOUT %d/%d %s %s %s seed=%d pair=%.6g attempts=%d\n',...
                h,planned,cases{a},modes{b},policies{b},seed,r.trackingMetrics.fault_pair_rms_rad,r.trackingMetrics.attempted_packets);
        end
    end
    checkpoint=vertcat(parts{:});writetable(checkpoint,fullfile(out,['checkpoint_' char(tag) '.csv']));
end
trials=vertcat(parts{:});assert(height(trials)==planned);
if isequal(caseIndices,1:8)
    writetable(trials,fullfile(out,'trials.csv'));save(fullfile(out,'tables.mat'),'trials');
else,writetable(trials,fullfile(out,['trials_part_' char(tag) '.csv']));end
fprintf('HELDOUT_BATCH_PASS: %d trials\n',height(trials));
end
