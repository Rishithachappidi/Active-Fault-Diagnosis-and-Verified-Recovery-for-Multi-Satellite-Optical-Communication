function o=sensor_view(y)
assert(numel(y)==26);o.angle=y(19:20);o.rate=y(21:22);o.power=y(23);
o.command=y(11:12);o.delivered=y(13:14);o.reference=y(1:2);
end

