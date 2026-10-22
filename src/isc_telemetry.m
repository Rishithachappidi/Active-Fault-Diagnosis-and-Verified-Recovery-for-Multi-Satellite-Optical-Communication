function v=isc_telemetry(z)
% First 36 = four [attitude(3), rate(3), torque(3)] columns.
sat=[z.att;z.rate;z.torque];
v=[sat(:);z.power(:);double(z.up(:));z.correction(:);z.label(:);...
    z.age(:);z.attempts(:);z.deliveries(:)];
assert(numel(v)==120);
end
