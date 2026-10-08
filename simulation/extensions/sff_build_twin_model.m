function mdl=sff_build_twin_model(C)
% Build a NEW Simulink model. Original sff_ets_model.slx is never overwritten.
% Requires MATLAB + Simulink; compile/runtime validation pending.
if nargin<1,C=sff_twin_config();end
here=fileparts(mfilename('fullpath'));addpath(fileparts(here));addpath(here);
P=sff_params();P.modelName='sff_twin_model';P.Ts=C.Ts;P.Tend=C.Tend;
mdl=sff_build_model(P);mws=get_param(mdl,'ModelWorkspace');assignin(mws,'CASE',4);
% Inline numeric configuration into each chart for fixed-size code generation.
literal='';names=fieldnames(C);
for k=1:numel(names),name=names{k};literal=[literal sprintf('C.%s = %s;\n',name,mat2str(C.(name),17))];end %#ok<AGROW>
rt=sfroot;
ctrl=rt.find('-isa','Stateflow.EMChart','Path',[mdl '/ControlAndTrigger']);
ctrl.Script=sprintf(['function [u,trig,chi,s] = control(t,x,mode)\n%%#codegen\n%s' ...
 '[u,trig,chi,s] = sff_twin_controller(t,x,mode,C);\nend\n'],literal);
plant=rt.find('-isa','Stateflow.EMChart','Path',[mdl '/SpacecraftDynamics']);
plant.Script=sprintf('function dx=plant(t,x,u)\n%%#codegen\n%sdx=sff_twin_plant(t,x,u,C);\nend\n',literal);
save_system(mdl,fullfile(here,[mdl '.slx']));
end
