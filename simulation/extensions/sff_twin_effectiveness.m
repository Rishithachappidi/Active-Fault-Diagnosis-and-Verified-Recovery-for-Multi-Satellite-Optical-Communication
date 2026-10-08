function G = sff_twin_effectiveness(t,C)
% Configurable fault truth; diagnosis never receives this function's output.
G = C.initialGamma;
for k=1:size(C.faults,1)
 f=C.faults(k,:); i=f(1);
 if i<1 || t<f(2), continue; end
 q=1;
 if f(4)==2, q=min(1,max(0,(t-f(2))/max(f(3),C.Ts))); end
 if f(4)==3, q=double(mod(floor((t-f(2))/max(f(8),C.Ts)),2)==0); end
 G(i,:)=G(i,:)*(1-q)+f(5:7)*q;
end
end
