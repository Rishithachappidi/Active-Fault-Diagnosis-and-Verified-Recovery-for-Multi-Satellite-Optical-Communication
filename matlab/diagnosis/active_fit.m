function [label,offset,gain,condition]=active_fit(X,z,c)
% z = log(P/P0)+2||theta_measured||^2/div^2;
% X = [1 theta_x/div theta_y/div]. Bias and optical offset confounded.
condition=rcond(X'*X);label=7;offset=[0;0];gain=NaN;
if size(X,1)<12 || condition<1e-4,return;end
beta=X\z;offset=-beta(2:3)*c.divergence/4;
gain=exp(beta(1)+2*sum(offset.^2)/c.divergence^2);
if norm(offset)>4e-6
 label=7; % Keep sensor/boresight ambiguity, including combined faults.
elseif gain<0.7
 label=4;
else,label=0;end
end

