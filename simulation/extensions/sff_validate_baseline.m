function report=sff_validate_baseline()
% Execute on a MATLAB-equipped machine to independently check the JS port.
% Expected JSON is a frozen PORT fixture, not certified paper ground truth.
here=fileparts(mfilename('fullpath'));root=fileparts(fileparts(here));
expected=jsondecode(fileread(fullfile(root,'baseline','regression.json')));
report=struct([]);
for mode=1:3
 R=sff_twin_run(mode);E=expected(mode);
 report(mode).mode=mode;report(mode).updates=sum(R.trig,1);
 report(mode).rmseDifference=abs(R.metrics.attitudeRMSE-E.metrics.attitudeRMSE);
 assert(isequal(report(mode).updates,reshape(E.updates,1,4)),'Trigger regression');
 assert(report(mode).rmseDifference<1e-8,'RMSE regression');
end
writelines(jsonencode(report),fullfile(root,'results','matlab-validation.json'));
end
