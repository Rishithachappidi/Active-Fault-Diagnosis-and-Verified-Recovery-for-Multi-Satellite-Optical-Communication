function trials=collect_holdout_experiments
root=fileparts(mfilename('fullpath'));out=fullfile(root,'results','holdout');
files={'trials_part_1_3.csv','trials_part_2_4.csv','trials_part_5_6_7_8.csv'};
parts=cell(3,1);for k=1:3,parts{k}=readtable(fullfile(out,files{k}),'TextType','string');end
trials=vertcat(parts{:});assert(height(trials)==440);
keys={'case_name','mode','policy','seed'};assert(height(unique(trials(:,keys)))==440);
cases=["principal_pointing","principal_combined","short_small","long_large",...
    "combined_new","severe_attenuation_new","beam_mismatch_new","alternate_tree_network"];
[ok,index]=ismember(trials.case_name,cases);assert(all(ok));
trials.caseOrder=index;trials=sortrows(trials,{'caseOrder','mode','policy','seed'});trials.caseOrder=[];
assert(all(trials.queue_overflows==0)&&all(trials.quaternion_norm_error<1e-12));
writetable(trials,fullfile(out,'trials.csv'));save(fullfile(out,'tables.mat'),'trials');
disp('HELDOUT_COLLECT_PASS: 440 unique trials');
end
