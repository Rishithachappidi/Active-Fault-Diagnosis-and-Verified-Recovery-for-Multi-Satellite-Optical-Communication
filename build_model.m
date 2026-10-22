function path=build_model(c)
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'src'));
if nargin<1,c=isc_tracking_config;end
name='IntegratedSatelliteControl';path=fullfile(root,[name '.slx']);
if bdIsLoaded(name),close_system(name,0);end
if isfile(path)
    load_system(path);Simulink.BlockDiagram.deleteContents(name);
else
    new_system(name);
end
set_param(name,'Solver','FixedStepDiscrete','FixedStep','c.dt','StopTime','c.T',...
    'ReturnWorkspaceOutputs','on','InitFcn',...
    'if ~exist(''c'',''var''), c=isc_tracking_config; end');
mw=get_param(name,'ModelWorkspace');mw.assignin('c',c);
add_block('simulink/User-Defined Functions/Level-2 MATLAB S-Function',[name '/Integrated physical and control kernel'],...
    'FunctionName','isc_sfunction','Parameters','c','Position',[70 170 275 270]);
add_block('simulink/Signal Routing/Demux',[name '/Satellite and network telemetry'],...
    'Outputs','[36 84]','Position',[330 155 335 290]);
add_line(name,'Integrated physical and control kernel/1','Satellite and network telemetry/1');
add_block('simulink/Signal Routing/Demux',[name '/Four spacecraft'],...
    'Outputs','[9 9 9 9]','Position',[395 40 400 230]);
add_line(name,'Satellite and network telemetry/1','Four spacecraft/1');
for i=1:4
    sub=[name '/SC' num2str(i) ' telemetry'];
    add_block('built-in/Subsystem',sub,'Position',[460 30+(i-1)*95 650 95+(i-1)*95]);
    add_block('simulink/Sources/In1',[sub '/attitude rate torque'],'Position',[25 38 55 52]);
    add_block('simulink/Signal Routing/Demux',[sub '/Signals'],'Outputs','[3 3 3]','Position',[95 20 100 100]);
    add_block('simulink/Sinks/Scope',[sub '/Attitude'],'Position',[160 5 190 35]);
    add_block('simulink/Sinks/Scope',[sub '/Rate'],'Position',[160 45 190 75]);
    add_block('simulink/Sinks/Scope',[sub '/Body torque'],'Position',[160 85 190 115]);
    add_line(sub,'attitude rate torque/1','Signals/1');
    add_line(sub,'Signals/1','Attitude/1');add_line(sub,'Signals/2','Rate/1');add_line(sub,'Signals/3','Body torque/1');
    add_line(name,['Four spacecraft/' num2str(i)],['SC' num2str(i) ' telemetry/1']);
end
add_block('simulink/Sinks/Scope',[name '/Embedded optical network telemetry'],...
    'Position',[460 445 650 505]);
add_line(name,'Satellite and network telemetry/2','Embedded optical network telemetry/1');
add_block('simulink/Sinks/To Workspace',[name '/Log live coupled simulation'],...
    'VariableName','isc_log','SaveFormat','Timeseries','Position',[330 540 550 575]);
add_line(name,'Integrated physical and control kernel/1','Log live coupled simulation/1','autorouting','on');
annotation=Simulink.Annotation(name,sprintf(['ONE COUPLED SYSTEM\nQuaternion rigid bodies -> terminal pointing -> optical power\n'...
    '-> delayed/lost state packets -> distributed attitude feedback\n'...
    'Kernel contains all live dynamics; SC panels expose each satellite.\n'...
    'Telemetry has one sample of output delay. See docs/MODEL.md.']));
annotation.Position=[65 15];
if isfield(c,'task') && strcmp(c.task,'leader_tracking')
    taskNote=Simulink.Annotation(name,sprintf(['MOVING-REFERENCE TASK\nOnly SC1 receives the external command.\n'...
        'Followers use delayed parent packets: SC1 -> SC2 -> SC3 -> SC4.\n'...
        'Known relative attitude offsets; local stabilization during outage.\n'...
        'Diagnosis-informed policies are optional ablations.']));
    taskNote.Position=[65 625];
end
save_system(name,path);fprintf('Created %s\n',path);
end
