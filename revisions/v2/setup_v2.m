function [v,root]=setup_v2
v=fileparts(mfilename('fullpath'));root=fileparts(fileparts(v));addpath(root);setup_project;addpath(v,fullfile(v,'models'));
end
