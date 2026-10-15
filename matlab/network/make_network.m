function edges=make_network(n,kind,seed)
assert(ismember(n,[4 6 8 10]));
edges=sort([(1:n)' [2:n 1]'],2);
if strcmp(kind,'mesh')
 chords=[(1:n/2)' (1:n/2)'+n/2];
 if n==4,chords=chords(1,:);end % Keep the smallest network non-complete.
 edges=[edges;chords];
elseif strcmp(kind,'random')
 rs=RandStream('mt19937ar','Seed',seed);
 for a=1:n,for b=a+1:n,if rand(rs)<0.18,edges(end+1,:)=[a b];end,end,end
elseif ~strcmp(kind,'ring'),error('Unknown topology');end
edges=unique(edges,'rows');
end

