function c=isc_holdout_config(caseName,mode,seed,policy)
if nargin<4,policy='off';end
scenario='pointing';if strcmp(caseName,'principal_combined')||strcmp(caseName,'combined_new'),scenario='combined';end
if strcmp(caseName,'severe_attenuation_new'),scenario='attenuation';end
c=isc_tracking_config(mode,scenario,seed,policy);c.caseName=caseName;
switch caseName
    case {'principal_pointing','principal_combined'}
    case 'short_small'
        c.pointingFaultScale=.6;c.faultStart=31;c.faultEnd=43;
    case 'long_large'
        c.pointingFaultScale=1.25;c.faultStart=18;c.faultEnd=63;
    case 'combined_new'
        c.pointingFaultScale=1.2;c.attenuationGain=.55;
        c.actuatorEffectiveness=[.25;.4;.3];c.faultStart=28;c.faultEnd=52;
    case 'severe_attenuation_new'
        c.attenuationGain=.08;c.faultStart=22;c.faultEnd=55;
    case 'beam_mismatch_new'
        c.plantDivergenceScale=.9;c.pointingFaultScale=.9;c.faultStart=20;c.faultEnd=58;
    case 'alternate_tree_network'
        c.parent=[0 1 1 2];c.activeEndpoints=[1 2 3 4 9 10];
        c.pointingFaultScale=1.1;c.delay=.2;c.jitter=.15;c.randomDrop=.10;
    otherwise,error('Unknown held-out condition');
end
% Exogenous randomness is isolated from the per-step channel RNG, and is
% identical across paired modes/policies for the same independent seed.
stream=RandStream('mt19937ar','Seed',seed+100000);
base=[.012 -.008 .009 -.011;-.006 .010 -.008 .007;.008 -.005 .006 -.009];
c.initialAngles=base+.002*randn(stream,3,4);
c.initialW=1e-4*randn(stream,3,4);
c.referencePhase=2*pi*rand(stream)-pi;
c.disturbancePhase=2*pi*rand(stream,3,4);
c.disturbanceScale=.7+.6*rand(stream,3,4);
end
