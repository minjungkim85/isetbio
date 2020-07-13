function runPhaseX(runParams)

    % Intermediate files directory
    saveDir = strrep(fileparts(which(mfilename())), 'processing', 'responseFiles');
    
    % Compute cone mosaic responses
    recomputeConeMosaicResponses = ~true;
    recomputeNullResponses = ~true;

    % Load/Recompute connected mosaics and the optics
    [theConeMosaic, theMidgetRGCmosaic, theOptics] = mosaicsAndOpticsForEccentricity(runParams, ~true, saveDir);

    % Stimulation parameters
    LMScontrast = [0.1 0.1 0.0];
    minSF = 0.1;
    maxSF = 60;
    spatialFrequenciesCPD = logspace(log10(minSF), log10(maxSF),12);
    
    
    stimulusFOVdegs = 2.0;
    minPixelsPerCycle = 10;
    stimulusPixelsNum = maxSF*stimulusFOVdegs*minPixelsPerCycle;
    temporalFrequency = 4.0;
    stimDurationSeconds = 0.5;
    instancesNum = 16;
    
    stimColor = struct(...
        'backgroundChroma', [0.3, 0.31], ...
        'meanLuminanceCdPerM2', 40, ...
        'lmsContrast', LMScontrast);
    
    stimTemporalParams = struct(...
        'temporalFrequencyHz', temporalFrequency, ...
        'stimDurationSeconds', stimDurationSeconds);
    
    stimSpatialParams = struct(...
        'type', 'driftingGrating', ...
        'fovDegs', stimulusFOVdegs,...
        'pixelsNum', stimulusPixelsNum, ...
        'gaborPosDegs', [0 0], ...
        'gaborSpatialFrequencyCPD', 0, ...
        'gaborSigmaDegs', Inf, ... %stimulusFOVdegs/(2*4), ...%Inf, ...
        'gaborOrientationDegs', 0, ...
        'deltaPhaseDegs', []);
    
    % Signal to the RGCs
    rgcInputSignal = 'isomerizations';
    %rgcInputSignal = 'photocurrents';
    
    if (recomputeConeMosaicResponses)
        computeConeResponses(runParams, ...
            stimColor,  stimTemporalParams, stimSpatialParams, ...
            theConeMosaic, theOptics, ...
            recomputeNullResponses, ...
            instancesNum, ...
            spatialFrequenciesCPD, ...
            saveDir);
    else
        computeRGCresponses(runParams, theConeMosaic, theMidgetRGCmosaic, ...
            rgcInputSignal, spatialFrequenciesCPD, LMScontrast, ...
            stimSpatialParams, stimTemporalParams, ...
            saveDir);
    end
end