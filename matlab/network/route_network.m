function r=route_network(c,available,power,quality)
% Dijkstra on operational edges only. All alternatives already established.
m=c.m;cost=c.distance/c.c+c.processing+c.packetBits/c.capacity;
W=inf(c.n);idx=zeros(c.n);
for j=1:m
 if available(j)
  a=c.edges(j,1);b=c.edges(j,2);W(a,b)=cost;W(b,a)=cost;idx(a,b)=j;idx(b,a)=j;
 end
end
d=inf(1,c.n);d(1)=0;prev=zeros(1,c.n);visited=false(1,c.n);
for k=1:c.n
 tmp=d;tmp(visited)=inf;[v,a]=min(tmp);if ~isfinite(v),break;end;visited(a)=true;
 for b=find(isfinite(W(a,:))),if d(a)+W(a,b)<d(b),d(b)=d(a)+W(a,b);prev(b)=a;end,end
end
r.path=[];r.edgeIDs=[];r.throughput=0;r.latency=NaN;r.pdr=0;
if ~isfinite(d(2)),return;end
r.path=2;while r.path(1)~=1,r.path=[prev(r.path(1)) r.path];end
for k=1:numel(r.path)-1,r.edgeIDs(k)=idx(r.path(k),r.path(k+1));end
assert(all(available(r.edgeIDs)),'Routing selected unavailable edge');
% Threshold receiver abstraction: fixed coding rate above sensitivity, no BER claim.
r.throughput=min(c.offered,c.capacity);r.pdr=r.throughput/c.offered;r.latency=d(2);
r.edge=struct('possible',true(m,1),'established',true(m,1),'operational',logical(available(:)),...
 'power_W',power(:),'quality',quality(:),'capacity_bps',c.capacity*available(:),...
 'reliability_proxy',min(1,quality(:)),'recoveryTime_s',nan(m,1),'cost_s',repmat(cost,m,1));
end

