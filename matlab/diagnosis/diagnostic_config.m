function d=diagnostic_config(c)
% Explicit whitelist: no truth labels, schedule, severity, or scenario.
keys={'Pt','eta','distance','divergence','aperture','sensitivity','method','tau','umax','decisionPeriod','probeAmplitude','probeDwell','maxCorrection','rateMax','powerNoise','detectRatio'};
d=struct;for k=1:numel(keys),d.(keys{k})=c.(keys{k});end
end

