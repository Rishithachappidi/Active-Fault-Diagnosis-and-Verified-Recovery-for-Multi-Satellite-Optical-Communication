function render_ci_layout
% Layout-only wrapper. Frozen numerical analysis and plotting source remain
% unchanged; pad categorical limits so endpoint tick labels are visible.
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);
oldLimits=get(groot,'defaultAxesXLim');oldMode=get(groot,'defaultAxesXLimMode');
cleanup=onCleanup(@()restore(oldLimits,oldMode)); %#ok<NASGU>
set(groot,'defaultAxesXLim',[.5 8.5],'defaultAxesXLimMode','manual');
plot_holdout_results;
end
function restore(limits,mode)
set(groot,'defaultAxesXLim',limits,'defaultAxesXLimMode',mode);
end
