%% 
function mdl = sff_build_model(P)
%SFF_BUILD_MODEL  Programmatically create the Simulink block diagram for the
%   event-triggered / self-triggered fault-tolerant attitude control system
%   of Xie/Sheng/Chen (IEEE TAES 2024).
%
%   The model is built from scratch, wired, laid out and saved as
%   <P.modelName>.slx.  Structure:
%
%     Clock ──┬─────────────────────────────┐
%             │                             │
%   Constant  │                             │
%   (CASE) ───┤                             │
%             ▼                             ▼
%        ControlAndTrigger ──► Saturation ──► SpacecraftDynamics ──► Integrator ──┐
%        (MATLAB Function)     (|u|<=umax)    (MATLAB Function)     (24 states)   │
%             ▲                                     ▲                             │
%             └─────────────────── state feedback ──┴─────────────────────────────┘
%
%   plus To-Workspace sinks for time, states, commanded torque, saturated
%   torque, trigger flags, chi and the sliding variable.

if nargin < 1, P = sff_params(); end
mdl = P.modelName;

% ---- start from a clean model ---------------------------------------
if bdIsLoaded(mdl), close_system(mdl, 0); end
if exist([mdl '.slx'],'file'), delete([mdl '.slx']); end
new_system(mdl);
open_system(mdl);

add = @(src,name,pos) add_block(src, [mdl '/' name], 'Position', pos);

% ===================== blocks =========================================
add('simulink/Sources/Clock',   'Clock',      [ 40  128   70  152]);
add('simulink/Sources/Constant','CaseSelect', [ 20  198  100  222]);
set_param([mdl '/CaseSelect'], 'Value', 'CASE');

add('simulink/User-Defined Functions/MATLAB Function', ...
    'ControlAndTrigger', [170  100  330  260]);
add('simulink/Discontinuities/Saturation', 'ActuatorSat', [390  113  430  147]);
set_param([mdl '/ActuatorSat'], ...
    'UpperLimit', 'umax', 'LowerLimit', '-umax');

add('simulink/User-Defined Functions/MATLAB Function', ...
    'SpacecraftDynamics', [490  100  650  200]);

add('simulink/Continuous/Integrator', 'States', [710  115  750  145]);
set_param([mdl '/States'], 'InitialCondition', 'x0');

% To-Workspace sinks
sinks = { 'ToWs_time','t_log'    ,[ 90  380  170  400]
          'ToWs_x'   ,'x_log'    ,[830  115  910  135]
          'ToWs_ucmd','ucmd_log' ,[390  310  470  330]
          'ToWs_usat','usat_log' ,[520  310  600  330]
          'ToWs_trig','trig_log' ,[390  360  470  380]
          'ToWs_chi' ,'chi_log'  ,[520  360  600  380]
          'ToWs_s'   ,'s_log'    ,[650  360  730  380] };
for q = 1:size(sinks,1)
    add('simulink/Sinks/To Workspace', sinks{q,1}, sinks{q,3});
    set_param([mdl '/' sinks{q,1}], ...
        'VariableName', sinks{q,2}, ...
        'SaveFormat',   'Array',    ...
        'SampleTime',   'Ts',       ...
        'MaxDataPoints','inf');
end

% ===================== MATLAB Function block sources ==================
here = fileparts(mfilename('fullpath'));
setMLFcnScript([mdl '/ControlAndTrigger'],  ...
    fileread(fullfile(here,'sff_controller_core.m')));
setMLFcnScript([mdl '/SpacecraftDynamics'], ...
    fileread(fullfile(here,'sff_plant_core.m')));

% The controller holds trigger memory in persistent variables, so it MUST be
% a discrete block executed exactly once per major step.
rtSF = sfroot;
ctrlChart = rtSF.find('-isa','Stateflow.EMChart','Path',[mdl '/ControlAndTrigger']);
ctrlChart.ChartUpdate = 'DISCRETE';
ctrlChart.SampleTime  = 'Ts';

% ===================== wiring =========================================
L = @(a,b) add_line(mdl, a, b, 'autorouting', 'smart');

L('Clock/1',              'ControlAndTrigger/1');
L('States/1',             'ControlAndTrigger/2');
L('CaseSelect/1',         'ControlAndTrigger/3');

L('ControlAndTrigger/1',  'ActuatorSat/1');
L('Clock/1',              'SpacecraftDynamics/1');
L('States/1',             'SpacecraftDynamics/2');
L('ActuatorSat/1',        'SpacecraftDynamics/3');
L('SpacecraftDynamics/1', 'States/1');

L('Clock/1',              'ToWs_time/1');
L('States/1',             'ToWs_x/1');
L('ControlAndTrigger/1',  'ToWs_ucmd/1');
L('ActuatorSat/1',        'ToWs_usat/1');
L('ControlAndTrigger/2',  'ToWs_trig/1');
L('ControlAndTrigger/3',  'ToWs_chi/1');
L('ControlAndTrigger/4',  'ToWs_s/1');

% ===================== solver configuration ===========================
cs = getActiveConfigSet(mdl);
set_param(cs, 'SolverType',        'Fixed-step');
set_param(cs, 'Solver',            'ode4');          % Runge-Kutta 4
set_param(cs, 'FixedStep',         'Ts');
set_param(cs, 'StartTime',         '0');
set_param(cs, 'StopTime',          'Tend');
set_param(cs, 'SaveOutput',        'off');
set_param(cs, 'SaveTime',          'off');
set_param(cs, 'ReturnWorkspaceOutputs', 'on');

% ---- model workspace: parameters live with the model ------------------
mws = get_param(mdl, 'ModelWorkspace');
assignin(mws, 'Ts',   P.Ts);
assignin(mws, 'Tend', P.Tend);
assignin(mws, 'umax', P.umax);
assignin(mws, 'x0',   sff_x0(P));
assignin(mws, 'CASE', 1);        % overwritten per run by sff_run_all

Simulink.BlockDiagram.arrangeSystem(mdl);
save_system(mdl);
end

% =====================================================================
function setMLFcnScript(blkPath, code)
%SETMLFCNSCRIPT  Write the body of a MATLAB Function block.
rt = sfroot;
ch = rt.find('-isa','Stateflow.EMChart','Path',blkPath);
if isempty(ch)
    error('sff:noChart','Could not locate MATLAB Function block %s', blkPath);
end
ch.Script = code;
end
