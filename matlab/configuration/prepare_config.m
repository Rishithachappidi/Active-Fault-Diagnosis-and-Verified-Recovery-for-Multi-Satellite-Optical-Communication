function c=prepare_config(c)
c.edges=make_network(c.n,c.topology,c.seed);c.m=size(c.edges,1);
N=ceil(c.T/c.dt)+5;c.noiseSamples=zeros(N,c.m,5);
for j=1:c.m
 rs=RandStream('mt19937ar','Seed',c.seed+1000*(j-1));
 c.noiseSamples(:,j,:)=reshape(randn(rs,N,5),N,1,5);
end
end

