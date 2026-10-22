function out=isc_pack(value,template)
% Numeric-only state serialization for Simulink DWork.
if nargin==1
    names=fieldnames(value);parts=cell(numel(names),1);
    for h=1:numel(names),parts{h}=value.(names{h})(:);end
    out=vertcat(parts{:});
else
    names=fieldnames(template);out=template;offset=0;
    for h=1:numel(names)
        shape=size(template.(names{h}));count=numel(template.(names{h}));
        out.(names{h})=reshape(value(offset+(1:count)),shape);offset=offset+count;
    end
    assert(offset==numel(value),'State length mismatch');
end
end
