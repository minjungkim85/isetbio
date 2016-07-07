function obj = irCompute(obj, outerSegment, varargin)
% rgcCompute: a method of @rgcPhys that computes the spiking output of the
% rgc mosaic to an arbitrary stimulus. These computations are carried
% out using code from Pillow, Shlens, Paninski, Sher, Litke, Chichilnisky,
% Simoncelli, Nature, 2008, licensed for modification, which can be found
% at 
% 
% http://pillowlab.princeton.edu/code_GLM.html
% 
% Inputs: outersegment.
% 
% Outputs: the rgc object with spiking responses.
% 
% Example:
% rgc1 = rgcCompute(rgc1, identityOS);
% 
% (c) isetbio
% 09/2015 JRG

% The superclass rgcCompute carries out convolution of the linear STRF:
obj = irCompute@ir(obj, outerSegment, varargin{:});

fprintf('     \n');
fprintf('Spike Generation:\n');
tic;
for cellTypeInd = 1%:length(obj.mosaic)
    % Call Pillow code to compute spiking outputs for N trials
    % spikeResponse = computeSpikesPhys(obj.mosaic{cellTypeInd,1}); 
    
%     spikeResponse = computeSpikesPhysPt(obj.mosaic{cellTypeInd,1});
    
%     spikeResponseFull = computeSpikesPhysCoupled(obj.mosaic{cellTypeInd,1},spikeResponse);

%     spikeResponseFull = computeSpikesPhysCoupled(obj.mosaic{cellTypeInd,1});

    [spikeResponseFull, spikeDrive, psthResponse, rollcomp] = computeSpikesPhysLab(obj.mosaic{cellTypeInd,1});
    obj.mosaic{cellTypeInd} = mosaicSet(obj.mosaic{cellTypeInd},'spikeResponse', spikeResponseFull);
    obj.mosaic{cellTypeInd} = mosaicSet(obj.mosaic{cellTypeInd},'responseSpikes', spikeResponseFull);
     obj.mosaic{cellTypeInd} = mosaicSet(obj.mosaic{cellTypeInd},'responseVoltage', spikeDrive);
    % Call Pillow code to compute rasters and PSTHs
%     [raster, psth] = computePSTH(obj.mosaic{cellTypeInd,1});
    obj.mosaic{cellTypeInd} = mosaicSet(obj.mosaic{cellTypeInd},'responseRaster', spikeResponseFull);
    obj.mosaic{cellTypeInd} = mosaicSet(obj.mosaic{cellTypeInd},'responsePsth', psthResponse);
        
    clear spikeResponseFull spikeDrive psthResponse raster psth
end
toc;



