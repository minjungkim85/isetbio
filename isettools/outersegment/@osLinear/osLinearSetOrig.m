function obj = osLinearSet(obj, param, val, varargin)
%Set isetbio outersegment object parameters
% 
% 
% 
% 
% 6/22/15 James Golden

if ~exist('param','var') || isempty(param)
    error('Parameter field required.');
end
if ~exist('val','var'),   error('Value field required.'); end;


param = ieParamFormat(param);  % Lower case and remove spaces
switch lower(param)

    case {'sconefilter'}
%         if ~((val == 0) || (val == 1))
%             error('noiseflag parameter must be 0 or 1.');
%         end
        obj.sConeFilter = val;
        
    case {'mconefilter'}
        obj.mConeFilter = val;
        
    case {'lconefilter'}
        obj.lConeFilter = val;
end

