function x=timeseries_matrix(ts)
n=numel(ts.Time);
if ts.IsTimeFirst,x=reshape(ts.Data,n,[]);else,x=reshape(ts.Data,[],n)';end
end

