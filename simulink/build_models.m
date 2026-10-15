function build_models(override)
root=setup_project;load_system('simulink');
if nargin,ns=override.n;else,ns=[0 4 6 8 10];end
for n=ns
 if n==0,cfg=prepare_config(default_config(4));cfg.m=1;cfg.edges=[1 2];name='OpticalLinkPointing';
 else,cfg=prepare_config(default_config(n));name=sprintf('SatelliteOpticalNetwork_%d',n);end
 if nargin,cfg=prepare_config(override);end
 if bdIsLoaded(name),close_system(name,0);end
 new_system(name);mw=get_param(name,'ModelWorkspace');assignin(mw,'cfg',cfg);
 set_param(name,'SolverType','Fixed-step','Solver','ode3','FixedStep','cfg.dt','StopTime','cfg.T','ReturnWorkspaceOutputs','on');
 add_block('simulink/User-Defined Functions/Level-2 MATLAB S-Function',[name '/Supervisor'],...
  'FunctionName','supervisor_sfun','Parameters','cfg','Position',[40 80 190 155]);
 add_block('simulink/Signal Routing/Demux',[name '/Commands'],'Outputs',repmat_dims(11,cfg.m),'Position',[235 50 240 100+85*cfg.m]);
 add_block('simulink/Signal Routing/Mux',[name '/Measurements'],'Inputs',num2str(cfg.m),'Position',[600 50 605 100+85*cfg.m]);
 add_line(name,'Supervisor/1','Commands/1');
 for j=1:cfg.m
  sub=[name sprintf('/OpticalTerminal_%02d',j)];add_block('built-in/Subsystem',sub,'Position',[310 40+85*j 535 100+85*j]);
  add_block('simulink/Sources/In1',[sub '/CommandsAndFaults'],'Port','1','Position',[25 40 55 60]);
  add_block('simulink/Continuous/Integrator',[sub '/PhysicalStates'],'InitialCondition','[cfg.initialAngle;zeros(6,1)]','Position',[350 150 390 190]);
  add_block('simulink/User-Defined Functions/MATLAB Function',[sub '/TwoAxisPlant_SMC_Actuator_Optics'],'Position',[170 20 350 120]);
  rt=sfroot;ch=rt.find('-isa','Stateflow.EMChart','Path',[sub '/TwoAxisPlant_SMC_Actuator_Optics']);
  ch.Script=fileread(fullfile(root,'simulink','terminal_kernel.m'));
  add_block('simulink/Sources/From Workspace',[sub '/MeasurementNoise'],'VariableName',sprintf('[(0:cfg.dt:cfg.dt*(size(cfg.noiseSamples,1)-1))'' squeeze(cfg.noiseSamples(:,%d,:))]',j),'Interpolate','off','OutputAfterFinalValue','Holding final value','Position',[20 100 120 130]);
  add_block('simulink/Sources/Constant',[sub '/PhysicalParameters'],'Value','terminal_parameters(cfg)','Position',[20 170 120 200]);
  add_block('simulink/Sinks/Out1',[sub '/Telemetry'],'Port','1','Position',[430 60 460 80]);
  add_line(sub,'CommandsAndFaults/1','TwoAxisPlant_SMC_Actuator_Optics/2');
  add_line(sub,'PhysicalStates/1','TwoAxisPlant_SMC_Actuator_Optics/1','autorouting','on');
  add_line(sub,'MeasurementNoise/1','TwoAxisPlant_SMC_Actuator_Optics/3');
  add_line(sub,'PhysicalParameters/1','TwoAxisPlant_SMC_Actuator_Optics/4');
  add_line(sub,'TwoAxisPlant_SMC_Actuator_Optics/1','PhysicalStates/1','autorouting','on');
  add_line(sub,'TwoAxisPlant_SMC_Actuator_Optics/2','Telemetry/1');
  add_line(name,sprintf('Commands/%d',j),sprintf('OpticalTerminal_%02d/1',j));
  add_line(name,sprintf('OpticalTerminal_%02d/1',j),sprintf('Measurements/%d',j));
 end
 add_line(name,'Measurements/1','Supervisor/1','autorouting','on');
 add_block('simulink/Sinks/To Workspace',[name '/PlantLog'],'VariableName','plantLog','SaveFormat','Timeseries','Position',[680 45 800 80]);
 add_block('simulink/Sinks/To Workspace',[name '/DecisionLog'],'VariableName','decisionLog','SaveFormat','Timeseries','Position',[235 10 355 35]);
 add_line(name,'Measurements/1','PlantLog/1');add_line(name,'Supervisor/2','DecisionLog/1');
 save_system(name,fullfile(root,'simulink',[name '.slx']));close_system(name,0);
end
end
function s=repmat_dims(d,m)
s=['[' strtrim(sprintf('%d ',repmat(d,1,m))) ']'];
end


