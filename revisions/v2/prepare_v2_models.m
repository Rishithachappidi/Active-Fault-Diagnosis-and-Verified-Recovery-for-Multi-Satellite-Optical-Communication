function prepare_v2_models
[v,root]=setup_v2;
for n=[4 6 8 10]
 old=sprintf('SatelliteOpticalNetwork_%d',n);name=[old '_v2'];target=fullfile(v,'models',[name '.slx']);
 if isfile(target),continue;end
 load_system(fullfile(root,'simulink',[old '.slx']));
 set_param([old '/Supervisor'],'FunctionName','supervisor_v2');
 add_block('simulink/Sinks/To Workspace',[old '/EstimatorLog'],'VariableName','estimatorLog','SaveFormat','Timeseries','Position',[400 10 540 40]);
 add_line(old,'Supervisor/3','EstimatorLog/1');
 save_system(old,target);bdclose('all');
end
end
