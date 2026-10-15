function root=setup_project
root=fileparts(mfilename('fullpath')); addpath(root,genpath(fullfile(root,'matlab')),fullfile(root,'simulink'),fullfile(root,'configs'));
end

