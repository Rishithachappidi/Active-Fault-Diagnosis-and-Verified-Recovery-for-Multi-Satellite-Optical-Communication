function start_v2
% Entry point for the final V2 distribution.
root=fileparts(mfilename('fullpath'));
addpath(fullfile(root,'revisions','v2'));
setup_v2;
open_system('SatelliteOpticalNetwork_4_v2');
fprintf('V2 ready. Read START_HERE.md for results and experiment commands.\n');
end
