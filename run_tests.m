function report=run_tests
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'src'),fullfile(root,'tests'));
report=test_integrated;
save(fullfile(root,'results','test_report.mat'),'report');
end
