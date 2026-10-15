function result=test_v2
[v,~]=setup_v2;result=runtests(fullfile(v,'tests'));
p=fullfile(v,'results',['tests_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);
save([p '.mat'],'result');writetable(table(result),[p '.csv']);assert(all([result.Passed]),'V2 tests failed');
end
