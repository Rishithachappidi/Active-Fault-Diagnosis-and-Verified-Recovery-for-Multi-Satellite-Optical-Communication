function here = int_setup()
%INT_SETUP  Paths for the integrated model: Project B (this repository),
%   Project B V2, Project A copy in integration/projectA, and integration/.
here = fileparts(mfilename('fullpath'));
root = fileparts(here);
addpath(fullfile(root, 'revisions', 'v2'));
setup_v2;                                   % Project B paths (matlab/, simulink/, configs/)
addpath(fullfile(here, 'projectA'));
addpath(here);
end
