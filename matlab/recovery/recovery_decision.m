function [correction,action]=recovery_decision(label,offset,gain,c)
correction=[0;0];action=1; % 1: route around unavailable links.
if label==7 && all(isfinite(offset)) && norm(offset)>4e-6
 correction=-offset;
 if norm(correction)>c.maxCorrection,correction=correction*c.maxCorrection/norm(correction);end
 action=3; % compensate observed optical gradient without claiming root cause.
elseif label==4,action=1;
elseif ismember(label,[2 3]),action=4; % persistent actuator maintenance needed.
end
if strcmp(c.method,'no_recovery'),correction=[0;0];action=1;end
end

