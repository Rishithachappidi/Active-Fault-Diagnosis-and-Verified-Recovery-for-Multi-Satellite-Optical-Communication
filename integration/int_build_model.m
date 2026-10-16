function mdl = int_build_model()
%INT_BUILD_MODEL  Build IntegratedFormationOptical.slx from the two
%   original projects plus one interface block.
%
%   Project A (unchanged code): ControlAndTrigger = sff_controller_core,
%   SpacecraftDynamics = int_plant_core -> sff_plant_core, Saturation,
%   24-state integrator, 1 kHz (ode4), exactly as sff_build_model.
%   Project B: Supervisor = supervisor_v2_los (copy of V2 diagnosis,
%   probing, correction, rollback, verification, routing) and one
%   terminal_kernel subsystem per optical link, as build_models.
%   Interface (new): AttitudeToLOS = int_attitude_to_los + CPA integrator.
%   Its output is ADDED to the command vector only in the optical-offset
%   slots u(9:10) of each link (physics), so neither controller's commands are
%   overwritten. In mode 3 it also sends the known residual to the supervisor
%   (supervisor_v2_los, a copy of supervisor_v2 that uses it in its optical
%   power model only).
here = fileparts(mfilename('fullpath'));
root = fileparts(here);
mdl  = 'IntegratedFormationOptical';
S = int_config();                             % for port sizes only
m = S.cfg.m;

load_system('simulink');
if bdIsLoaded(mdl), close_system(mdl, 0); end
new_system(mdl);
mw = get_param(mdl, 'ModelWorkspace');
vars = {'Ts','Tend','umax','x0','CASE','cfg','distData','c0','MODE','TAUCPA','TACQ'};
for k = 1:numel(vars), assignin(mw, vars{k}, S.(vars{k})); end
assignin(mw, 'TX', S.tx);
add = @(src, name, pos) add_block(src, [mdl '/' name], 'Position', pos);
L = @(a, b) add_line(mdl, a, b, 'autorouting', 'smart');

% ================= Project A =================
add('simulink/Sources/Clock', 'Clock', [40 130 70 150]);
add('simulink/Sources/Constant', 'CaseSelect', [20 200 100 220]); set_param([mdl '/CaseSelect'], 'Value', 'CASE');
add('simulink/User-Defined Functions/MATLAB Function', 'ControlAndTrigger', [170 100 330 260]);
add('simulink/Discontinuities/Saturation', 'ActuatorSat', [390 113 430 147]);
set_param([mdl '/ActuatorSat'], 'UpperLimit', 'umax', 'LowerLimit', '-umax');
add('simulink/Sources/From Workspace', 'DisturbanceTorque', [330 300 450 330]);
set_param([mdl '/DisturbanceTorque'], 'VariableName', 'distData', 'Interpolate', 'off', 'OutputAfterFinalValue', 'Holding final value');
add('simulink/User-Defined Functions/MATLAB Function', 'SpacecraftDynamics', [490 100 650 220]);
add('simulink/Continuous/Integrator', 'States', [710 115 750 145]);
set_param([mdl '/States'], 'InitialCondition', 'x0');

setScript([mdl '/ControlAndTrigger'], fullfile(here, 'projectA', 'sff_controller_core.m'));
setScript([mdl '/SpacecraftDynamics'], fullfile(here, 'int_plant_core.m'));
rt = sfroot;
ch = rt.find('-isa', 'Stateflow.EMChart', 'Path', [mdl '/ControlAndTrigger']);
ch.ChartUpdate = 'DISCRETE'; ch.SampleTime = 'Ts';     % same as Project A

L('Clock/1', 'ControlAndTrigger/1'); L('States/1', 'ControlAndTrigger/2'); L('CaseSelect/1', 'ControlAndTrigger/3');
L('ControlAndTrigger/1', 'ActuatorSat/1');
L('Clock/1', 'SpacecraftDynamics/1'); L('States/1', 'SpacecraftDynamics/2');
L('ActuatorSat/1', 'SpacecraftDynamics/3'); L('DisturbanceTorque/1', 'SpacecraftDynamics/4');
L('SpacecraftDynamics/1', 'States/1');

% ================= Interface =================
add('simulink/User-Defined Functions/MATLAB Function', 'AttitudeToLOS', [820 300 1000 460]);
setScript([mdl '/AttitudeToLOS'], fullfile(here, 'int_attitude_to_los.m'));
add('simulink/Continuous/Integrator', 'CoarsePointingState', [1060 380 1100 410]);
set_param([mdl '/CoarsePointingState'], 'InitialCondition', 'c0');
consts = {'Mode','MODE'; 'TauCPA','TAUCPA'; 'AcqTime','TACQ'; 'Transmitters','TX'};
for q = 1:4
    add('simulink/Sources/Constant', consts{q,1}, [700 330+35*q 760 350+35*q]);
    set_param([mdl '/' consts{q,1}], 'Value', consts{q,2});
end
L('Clock/1', 'AttitudeToLOS/1'); L('States/1', 'AttitudeToLOS/2'); L('CoarsePointingState/1', 'AttitudeToLOS/3');
for q = 1:4, L([consts{q,1} '/1'], sprintf('AttitudeToLOS/%d', q + 3)); end
L('AttitudeToLOS/2', 'CoarsePointingState/1');

% ================= Project B =================
add('simulink/User-Defined Functions/Level-2 MATLAB S-Function', 'Supervisor', [1060 520 1210 600]);
set_param([mdl '/Supervisor'], 'FunctionName', 'supervisor_v2_los', 'Parameters', 'cfg');
add('simulink/Math Operations/Sum', 'AddAttitudeCoupling', [1250 520 1280 600]);
set_param([mdl '/AddAttitudeCoupling'], 'Inputs', '++');
add('simulink/Signal Routing/Demux', 'Commands', [1320 500 1325 550 + 85*m]);
set_param([mdl '/Commands'], 'Outputs', ['[' strtrim(sprintf('%d ', repmat(11, 1, m))) ']']);
add('simulink/Signal Routing/Mux', 'Measurements', [1650 500 1655 550 + 85*m]);
set_param([mdl '/Measurements'], 'Inputs', num2str(m));
L('Supervisor/1', 'AddAttitudeCoupling/1'); L('AttitudeToLOS/1', 'AddAttitudeCoupling/2');
L('AddAttitudeCoupling/1', 'Commands/1');
kern = fileread(fullfile(root, 'simulink', 'terminal_kernel.m'));
for j = 1:m
    sub = [mdl sprintf('/OpticalTerminal_%02d', j)];
    add_block('built-in/Subsystem', sub, 'Position', [1380 480 + 85*j 1600 540 + 85*j]);
    add_block('simulink/Sources/In1', [sub '/CommandsAndFaults'], 'Position', [25 40 55 60]);
    add_block('simulink/Continuous/Integrator', [sub '/PhysicalStates'], 'InitialCondition', '[cfg.initialAngle;zeros(6,1)]', 'Position', [350 150 390 190]);
    add_block('simulink/User-Defined Functions/MATLAB Function', [sub '/TwoAxisPlant_SMC_Actuator_Optics'], 'Position', [170 20 350 120]);
    c2 = rt.find('-isa', 'Stateflow.EMChart', 'Path', [sub '/TwoAxisPlant_SMC_Actuator_Optics']); c2.Script = kern;
    add_block('simulink/Sources/From Workspace', [sub '/MeasurementNoise'], 'VariableName', ...
        sprintf('[(0:cfg.dt:cfg.dt*(size(cfg.noiseSamples,1)-1))'' squeeze(cfg.noiseSamples(:,%d,:))]', j), ...
        'Interpolate', 'off', 'OutputAfterFinalValue', 'Holding final value', 'Position', [20 100 120 130]);
    add_block('simulink/Sources/Constant', [sub '/PhysicalParameters'], 'Value', 'terminal_parameters(cfg)', 'Position', [20 170 120 200]);
    add_block('simulink/Sinks/Out1', [sub '/Telemetry'], 'Position', [430 60 460 80]);
    add_line(sub, 'CommandsAndFaults/1', 'TwoAxisPlant_SMC_Actuator_Optics/2');
    add_line(sub, 'PhysicalStates/1', 'TwoAxisPlant_SMC_Actuator_Optics/1', 'autorouting', 'on');
    add_line(sub, 'MeasurementNoise/1', 'TwoAxisPlant_SMC_Actuator_Optics/3');
    add_line(sub, 'PhysicalParameters/1', 'TwoAxisPlant_SMC_Actuator_Optics/4');
    add_line(sub, 'TwoAxisPlant_SMC_Actuator_Optics/1', 'PhysicalStates/1', 'autorouting', 'on');
    add_line(sub, 'TwoAxisPlant_SMC_Actuator_Optics/2', 'Telemetry/1');
    L(sprintf('Commands/%d', j), sprintf('OpticalTerminal_%02d/1', j));
    L(sprintf('OpticalTerminal_%02d/1', j), sprintf('Measurements/%d', j));
end
L('Measurements/1', 'Supervisor/1');
L('AttitudeToLOS/5', 'Supervisor/2');        % known LOS offset (non-zero in mode 3 only)

% ================= Logging =================
logs = {'PlantLog','plantLog','Measurements/1','Timeseries','cfg.dt'
        'DecisionLog','decisionLog','Supervisor/2','Timeseries','-1'
        'EstimatorLog','estimatorLog','Supervisor/3','Timeseries','-1'
        'AttitudeLog','x_log','States/1','Array','cfg.dt'
        'TriggerLog','trig_log','ControlAndTrigger/2','Array','Ts'
        'LOSLog','phi_log','AttitudeToLOS/3','Array','cfg.dt'
        'ResidualLog','resid_log','AttitudeToLOS/4','Array','cfg.dt'
        'TimeLog','t_log','Clock/1','Array','cfg.dt'};
for q = 1:size(logs, 1)
    add('simulink/Sinks/To Workspace', logs{q,1}, [1750 60*q 1870 60*q+25]);
    set_param([mdl '/' logs{q,1}], 'VariableName', logs{q,2}, 'SaveFormat', logs{q,4}, 'SampleTime', logs{q,5}, 'MaxDataPoints', 'inf');
    L(logs{q,3}, [logs{q,1} '/1']);
end

% ================= Solver (Project A's: fixed-step ode4, 1 ms) =================
set_param(mdl, 'SolverType', 'Fixed-step', 'Solver', 'ode4', 'FixedStep', 'Ts', 'StopTime', 'Tend', ...
    'ReturnWorkspaceOutputs', 'on');
save_system(mdl, fullfile(here, [mdl '.slx']));
close_system(mdl, 0);
end

function setScript(blk, file)
rt = sfroot;
ch = rt.find('-isa', 'Stateflow.EMChart', 'Path', blk);
ch.Script = fileread(file);
end
