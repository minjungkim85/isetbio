function varargout = v_osLinearObjectTemp(varargin)
%
% Validate the linear model of the cone outer segments.
%
% This script tests out our implementation of a biophysical model of the
% isomerizations to photocurrent transduction process that occurs in the
% cone outer segments.
%
% More specifically, this compares the DEQ based outer segment model output with several key
% measured properties of the cone photocurrent responses:
%   - impulse response in the dark
%   - responses to steps + flashes to measure kinetics of step response and
%     adaptation of step and flash responses
%   - responses to stimuli designed to mimic those encountered by a cone
%     during saccades about a natural scene
%   - responses to light increments and decrements
%
% References for original data:
%       Dunn et al. (2007)
%       Angueyra and Rieke (2013)
%
% At present, what this does is verify that the current outersegment object
% does the same thing as the routines from which it was built, namely those
% supplied by Fred.  This is really an interim step, as this just ensures
% that we didn't introduce any bugs when we built the object.  Once we have
% that checked, we can toss the old code and then validate what the
% outersegement object does directly against underlying measurements.
%
% 6/2015 FMR   Created.
% 7/2015 JRG   Test with ISETBIO outersegment object

    varargout = UnitTest.runValidationRun(@ValidationFunction, nargout, varargin);
end

%% Function implementing the isetbio validation code
function ValidationFunction(runTimeParams)


%% Init
ieInit;

%% Impulse response in dark
%
% We'll compare the original code and the outer segment object for this
% case.
%
% Set up parameters for stimulus
nSamples = 2000;        % 2000 samples
timeStep = 1e-4;        % time step
flashIntens = 50000;    % flash intensity in R*/cone/sec (maintained for 1 bin only)

% Create human sensor
sensor = sensorCreate('human');
sensor = sensorSet(sensor, 'size', [1 1]); % only 1 cone
sensor = sensorSet(sensor, 'time interval', timeStep); 

% Create stimulus
stimulus = zeros(nSamples, 1);
stimulus(1) = flashIntens;
stimulus = reshape(stimulus, [1 1 nSamples]);

% Set photon rates
sensor = sensorSet(sensor, 'photon rate', stimulus);

% Compute model current and baseline correct
params.bgVolts  = 0;
[~, adaptedCur] = coneAdapt(sensor, 'linear', params);
adaptedCur(:) = adaptedCur(:) - adaptedCur(:, :, nSamples); % removes offset

% Create outersegment object and get the adapted response.
noiseFlag = 0;
% adaptedOS = osLinear();
adaptedOS = osLinear('noiseFlag', noiseFlag);
% paramsOS.dc = 0; % removes offset
sensor = sensorSet(sensor,'adaptation offset',params.bgVolts);
sensor = sensorSet(sensor,'cone type', 2); % set s cone
% adaptedOS = adaptedOS.compute(sensor);
adaptedOS = osLinearCompute(adaptedOS, sensor);
osAdaptedCur = osLinearGet(adaptedOS, 'ConeCurrentSignal');
osAdaptedCur = osAdaptedCur - osAdaptedCur(:, :, nSamples);

osLinearPlot(adaptedOS, sensor);

% Plot a comparison of the two.  These should be identical since we
% think they are the same code doing the same thing. 
% if (runTimeParams.generatePlots)
    figure; clf; hold on
    tme = (1:nSamples)*timeStep;
    plot(tme,squeeze(adaptedCur),'r','LineWidth',3);
    plot(tme,squeeze(osAdaptedCur),'k:','LineWidth',2);
    xlabel('sec','FontSize',14);
    ylabel('pA','FontSize',14);
    title('impulse response in the dark','FontSize',16);
    legend('original code model resp', 'osBioPhys object resp');
% end
tolerance = 1e-3;
UnitTest.assertIsZero(max(abs(adaptedCur-osAdaptedCur)),'Comparison for dark impulse response',tolerance);
UnitTest.validationData('adaptedCur',adaptedCur);
UnitTest.validationData('osAdaptedCur',osAdaptedCur);

% end%function

% % Compute fit to measured response (Angueyra and Rieke, 2013)
% coef = [1 0.05 0.1 1 0];
% tme = (1:nSamples)*timeStep;
% impcoef = nlinfit(tme', squeeze(adaptedCur), 'ConeEmpiricalDimFlash', coef);
% fit = ConeEmpiricalDimFlash(impcoef, tme'); 
% warning('off', 'stats:nlinfit:ModelConstantWRTParam');
% warning('off', 'MATLAB:rankDeficientMatrix');
% expcoef = [5 0.02 0.03 0.53 34];            % fit to measured response
% expfit = ConeEmpiricalDimFlash(expcoef, tme');
% 
% % Compare model vs empirical fit to data
% figure(1); clf;
% if noiseFlag == 0
%     plot(tme, fit, tme, squeeze(adaptedCur), tme, expfit, tme, squeeze(adaptedOS.ConeCurrentSignal));
% elseif noiseFlag == 1
%     plot(tme, fit, tme, squeeze(adaptedCur), tme, expfit, tme, squeeze(adaptedOS.ConeCurrentSignalPlusNoise));
% end
% xlabel('sec');
% ylabel('pA');
% title('impulse response');
% legend('model fit', 'model resp', 'exp fit', 'osBioPhys resp');

clear adaptedOS paramsOS
%% steps + flashes

%  set up parameters for stimulus
stimPeriod = [4000 22000];          % start and end time of step
nSamples = stimPeriod(2)+4000;      % number of samples
timeStep = 1e-4;                    % time step
flashTime = stimPeriod - 3000;      % time of flashes
flashDur = 10;                      % flash duration (bins)
flashIntens = 10000;                % flash intensity R*/cone/sec
%  create human sensor
sensor = sensorCreate('human');
sensor = sensorSet(sensor, 'size', [1 1]); % only 1 cone
sensor = sensorSet(sensor, 'time interval', timeStep);

h1 = figure(1); clf; subplot(1, 4, 1); hold on; subplot(1, 4, 2); hold on; subplot(1, 4, 3); hold on
subplot(1,4,4); hold on;

xlabel('sec');
ylabel('pA');

clear SSCur stimIntensity FlashAmp
FlashScFact = 1;                     % scaling of flash to compensate adaptation

% go through series of step intensities (slow)
for step = 1:11
    
    %  create stimulus: step alone
    stimIntensity(step) = 50 * 2^step;          
    stimulus = zeros(nSamples, 1);
    stimulus(stimPeriod(1):stimPeriod(2)) = stimIntensity(step);
    stimulus = reshape(stimulus, [1 1 nSamples]);
    
    % increase flash strength if we are in range where cones adapting
    if (stimIntensity(step) > 4000);
        FlashScFact = FlashScFact * 2;
    end
    
    % set photon rates
    sensor = sensorSet(sensor, 'photon rate', stimulus);

    % compute adapted current
    params.bgVolts  = 0;
    [~, adaptedCurStepOnly] = coneAdapt(sensor, 'linear', params);
    
    % Create outersegment object
    noiseFlag = 0;
    adaptedOSStepOnly = osLinear('noiseFlag', noiseFlag);
    
    sensor = sensorSet(sensor,'adaptation offset',params.bgVolts);
    % paramsOSStepOnly.bgVolts = params.bgVolts;
    % paramsOSStepOnly.dc = 0; % removes dc
    % adaptedOSStepOnly = adaptedOSStepOnly.compute(sensor, paramsOSStepOnly);
    adaptedOSStepOnly = osLinearCompute(adaptedOSStepOnly, sensor);
    % adaptedOs.plotResults(sensor)

    %  create stimulus: step + flashes
    stimulus = zeros(nSamples, 1);
    stimulus(stimPeriod(1):stimPeriod(2)) = stimIntensity(step);
    stimulus(flashTime(1):flashTime(1)+flashDur) = stimulus(flashTime(1):flashTime(1)+flashDur) + flashIntens;
    stimulus(flashTime(2):flashTime(2)+flashDur) = stimulus(flashTime(2):flashTime(2)+flashDur) + flashIntens*FlashScFact;
    stimulus = reshape(stimulus, [1 1 nSamples]);

    % set photon rates
    sensor = sensorSet(sensor, 'photon rate', stimulus);

    % compute adapted current
    params.bgVolts  = 0;
    [~, adaptedCur] = coneAdapt(sensor, 'linear', params);
    
    % Create outersegment object
%     noiseFlag = 0;
%     adaptedOS = osBioPhys('noiseFlag', noiseFlag);
%     paramsOS.bgVolts = params.bgVolts;
%     % paramsOS.dc = 0; % removes dc
%     adaptedOS = adaptedOS.compute(sensor, paramsOS);
%     % adaptedOs.plotResults(sensor)
    
    
    noiseFlag = 0;
    adaptedOS = osLinear('noiseFlag', noiseFlag);
    
    sensor = sensorSet(sensor,'adaptation offset',params.bgVolts);
    % paramsOSStepOnly.bgVolts = params.bgVolts;
    % paramsOSStepOnly.dc = 0; % removes dc
    % adaptedOSStepOnly = adaptedOSStepOnly.compute(sensor, paramsOSStepOnly);
    adaptedOS = osLinearCompute(adaptedOS, sensor);

    % plot
    subplot(1, 4, 1);
    plot((1:nSamples)*timeStep, adaptedCur(:), 'k', 'lineWidth', 2);
    subplot(1, 4, 2);
    plot((1:nSamples)*timeStep, adaptedCurStepOnly(:), 'k', 'lineWidth', 2);
    subplot(1, 4, 3);
    plot((1:nSamples)*timeStep, adaptedCur(:) - adaptedCurStepOnly(:), 'k', 'lineWidth', 2);
    temp = adaptedCur(:) - adaptedCurStepOnly(:);
       
    subplot(1, 4, 4);
    plot((1:nSamples)*timeStep, adaptedOS.ConeCurrentSignal(:) - adaptedOSStepOnly.ConeCurrentSignal(:), 'k', 'lineWidth', 2);
    tempOS = adaptedOS.ConeCurrentSignal(:) - adaptedOSStepOnly.ConeCurrentSignal(:);
    pause(0.1);

    % summary statistics
    FlashAmp(step) = max(temp(flashTime(2):flashTime(2)+1000)) / (FlashScFact * max(temp(flashTime(1):flashTime(1)+1000)));
    SSCur(step) = -(adaptedCurStepOnly(1, 1, stimPeriod(2)) - adaptedCurStepOnly(1, 1, 1))/adaptedCurStepOnly(1, 1, 1);
    [MaxVal, MaxLoc] = max(temp(flashTime(2):flashTime(2)+1000));
    TPeak(step) = MaxLoc*timeStep;
    
    FlashAmpOS(step) = max(tempOS(flashTime(2):flashTime(2)+1000)) / (FlashScFact * max(tempOS(flashTime(1):flashTime(1)+1000)));
    SSCurOS(step) = -(adaptedOSStepOnly.ConeCurrentSignal(1, 1, stimPeriod(2)) - adaptedOSStepOnly.ConeCurrentSignal(1, 1, 1))/adaptedOSStepOnly.ConeCurrentSignal(1, 1, 1);
    
    % fit transient of step response
    Transient = adaptedCurStepOnly(stimPeriod(1)+round(6e-2/timeStep):stimPeriod(2));
    Transient = Transient - Transient(length(Transient));
    
    TransientOS = adaptedOSStepOnly.ConeCurrentSignal(stimPeriod(1)+round(6e-2/timeStep):stimPeriod(2));
    TransientOS = TransientOS - TransientOS(length(Transient));
    
end

subplot(1, 4, 3); title('coneAdapt');
subplot(1, 4, 4); title('osBioPhys');

% % fit steady-state stimulus-response relation
% % half max 45000 (Dunn et al 2007)
% figure(2);clf;
% subplot(1,2,1);
% semilogx(stimIntensity, SSCur, 'o');
% hold on;
% coef = [45000 1];
% % fitcoef = nlinfit(stimIntensity, SSCur, 'hill', coef);
% % fit = hill(fitcoef, stimIntensity);
% % semilogx(stimIntensity, fit);
% xlabel('background');
% ylabel('steady-state current');
% axis tight;
% title('coneAdapt ');
% 
% subplot(1,2,2);
% semilogx(stimIntensity, SSCurOS, 'o');
% hold on;
% coef = [45000 1];
% fitcoef = nlinfit(stimIntensity, SSCurOS, 'hill', coef);
% fit = hill(fitcoef, stimIntensity);
% semilogx(stimIntensity, fit);
% xlabel('background');
% ylabel('steady-state current');
% axis tight;
% title('osBioPhys Object ');

% fit sensitivity vs intensity relation
% half desens around 2500 (Angueyra and Rieke, 2013)
figure(3);clf;
% subplot(1,2,1);
loglog(stimIntensity, FlashAmp, 'ro');
hold on;
coef = [2500];
% wfcoef = nlinfit(stimIntensity, log10(FlashAmp), 'weber_fechner', coef);
% fit = weber_fechner(wfcoef, stimIntensity);
% loglog(stimIntensity, 10.^fit);
xlabel('background');
ylabel('sensitivity');
axis tight;
title('coneAdapt ');

% subplot(1,2,2);
loglog(stimIntensity, FlashAmpOS, 'kx');
hold on;
coef = [2500];
% wfcoef = nlinfit(stimIntensity, log10(FlashAmpOS), 'weber_fechner', coef);
% fit = weber_fechner(wfcoef, stimIntensity);
% loglog(stimIntensity, 10.^fit);
xlabel('background');
ylabel('sensitivity');
axis tight;
title('osBioPhys Object ');
axis([1e2 1e5 0.9 1.1]);
legend('coneAdapt','osLinear');

% fit current transient - two temporal components which contrast fast and
% slow Calcium feedback terms
% 3:1 ratio of amps, rate constants 1 and 12
tme = (1:length(Transient))*timeStep;
coef = [1 1 3 12];
stepcoef = nlinfit(tme', squeeze(Transient), 'dblexponentialnomean', coef);
fit = dblexponentialnomean(stepcoef,  tme);
figure(4); clf
% subplot(1,2,1);
plot(tme, Transient(:),'r','Linewidth',3);%, tme, fit);
xlabel('time');
ylabel('pA');
title('coneAdapt ');

% subplot(1,2,2);
hold on;
plot(tme, TransientOS(:),':k','Linewidth',2);%, tme, fit);
xlabel('time');
ylabel('pA');
title('osBioPhys Object ');

% fprintf(1, 'half max step amp = %d\nhalf desensitizing background = %d\nstep time constants = %d and %d\n', fitcoef(1), wfcoef(1), stepcoef(2), stepcoef(4));
% fprintf(1, 'targets: half max step amp = 45000 R*/cone/sec\n\thalf desensitizing background = 2500 R*/cone/sec \n\tstep time constants = 1 and 12 sec\n');

tolerance = 1e-8;
UnitTest.assertIsZero(max(abs(FlashAmp(:)-FlashAmpOS(:))),'Comparison for dark impulse response',tolerance);
UnitTest.validationData('adaptedCur',adaptedCur);
UnitTest.validationData('osAdaptedCur',osAdaptedCur);


clear adaptedOS adaptedOSSteponly paramsOS paramsOSStepOnly


% end%function
%% saccade-like stimuli

% load experimental data and baseline correct
load('ConeData/EyeMovementsExample.mat');
measuredCur = EyeMovementsExample.Mean - EyeMovementsExample.Mean(length(EyeMovementsExample.Mean));

%  create stimulus
stimulus = EyeMovementsExample.Stim;
nSamples = length(stimulus);
stimulus = reshape(stimulus, [1 1 nSamples]);

% Compute adapted current using DEQ model

%  create human sensor
sensor = sensorCreate('human');
sensor = sensorSet(sensor, 'size', [1 1]); % only 1 cone
sensor = sensorSet(sensor, 'time interval', 5e-5);

% set photon rates
sensor = sensorSet(sensor, 'photon rate', stimulus);

% compute adapted current
params.bgVolts  = 0;
[~, adaptedCur] = coneAdapt(sensor, 'linear', params);
adaptedCur = adaptedCur - adaptedCur(:, :, length(stimulus));

% Create outersegment object
noiseFlag = 0;
adaptedOS = osLinear('noiseFlag', noiseFlag);
% paramsOS.bgVolts = params.bgVolts;
% paramsOS.dc = 0; % removes dc

sensor = sensorSet(sensor,'adaptation offset',params.bgVolts);
% adaptedOS = adaptedOS.compute(sensor, paramsOS);
adaptedOS = osLinearCompute(adaptedOS, sensor);
% adaptedOs.plotResults(sensor)

osAdaptedCur = osLinearGet(adaptedOS, 'ConeCurrentSignal');
osAdaptedCur = osAdaptedCur - osAdaptedCur(:, :, nSamples);

% plot against measurement data
figure(5); 
clf;
% subplot(1,2,1);
hold on;
% plot((1:nSamples)*5e-5, measuredCur(1,:));
plot((1:nSamples)*5e-5, adaptedCur(:), 'r', 'LineWidth', 3);
axis tight
xlabel('sec');
ylabel('pA');
title('coneAdapt');

% subplot(1,2,2);
hold on;
% plot((1:nSamples)*5e-5, measuredCur(1,:));
plot((1:nSamples)*5e-5, osAdaptedCur(:), 'k:', 'LineWidth', 2);
axis tight
xlabel('sec');
ylabel('pA');
title('osLinear');
legend('coneAdapt','osLinear');

% Check computation in osBioPhys is the same as adaptedCur
% sum(adaptedCur(:) - adaptedOS.ConeCurrentSignal(:))
% figure; scatter(adaptedCur(:), adaptedOS.ConeCurrentSignal(:));

tolerance = 1e-8;
UnitTest.assertIsZero(max(abs(adaptedCur-osAdaptedCur)),'Comparison for dark impulse response',tolerance);
UnitTest.validationData('adaptedCur',adaptedCur);
UnitTest.validationData('osAdaptedCur',osAdaptedCur);


% clear adaptedOS paramsOS
%% increment/decrement asymmetry

%  set up parameters for stimulus
stimPeriod = [5000 7500]; % start and end time of step
nSamples = stimPeriod(2)+5000;
timeStep = 2e-4;
Contrast = 1;

%  create human sensor
sensor = sensorCreate('human');
sensor = sensorSet(sensor, 'size', [1 1]); % only 1 cone
sensor = sensorSet(sensor, 'time interval', timeStep);

figure(1); clf;
clear MaxInc MaxDec stimIntensity;

% predict responses to increments and decrements across range of light
% levels
for step = 1:7
    
    %  create stimulus: step alone
    stimIntensity(step) = 250 * 2^step;          % photons per second
    stimulusInc = zeros(nSamples, 1);
    stimulusInc(100:nSamples-100) = stimIntensity(step);
    stimulusInc(stimPeriod(1):stimPeriod(2)) = stimIntensity(step)*(1 + Contrast);
    stimulus = reshape(stimulusInc, [1 1 nSamples]);

    % set photon rates
    sensor = sensorSet(sensor, 'photon rate', stimulus);

    % compute adapted current
    params.bgVolts  = 0;
    [~, adaptedCurInc] = coneAdapt(sensor, 'linear', params);
    
    % Create outersegment object
    noiseFlag = 0;
    adaptedOSInc = osLinear('noiseFlag', noiseFlag);
%     paramsOSInc.bgVolts = params.bgVolts;
    % paramsOS.dc = 0; % removes dc
    sensor = sensorSet(sensor,'cone type', 2); % set s cone
    sensor = sensorSet(sensor,'adaptation offset',params.bgVolts);
%     adaptedOSInc = adaptedOSInc.compute(sensor, paramsOSInc);
    adaptedOSInc = osLinearCompute(adaptedOSInc, sensor);
    % adaptedOs.plotResults(sensor)

    %  create stimulus: step + flashes
    stimulusDec = zeros(nSamples, 1);
    stimulusDec(100:nSamples-100) = stimIntensity(step);
    stimulusDec(stimPeriod(1):stimPeriod(2)) = stimIntensity(step)*(1 - Contrast);
    stimulus = reshape(stimulusDec, [1 1 nSamples]);

    % set photon rates
    sensor = sensorSet(sensor, 'photon rate', stimulus);

    % compute adapted current
    params.bgVolts  = 0;
    [~, adaptedCurDec] = coneAdapt(sensor, 'linear', params);
    
    % Create outersegment object
    noiseFlag = 0;
    adaptedOSDec = osLinear('noiseFlag', noiseFlag);
    
    sensor = sensorSet(sensor,'adaptation offset',params.bgVolts);
%     paramsOSDec.bgVolts = params.bgVolts;
    % paramsOS.dc = 0; % removes dc
%     adaptedOSDec = adaptedOSDec.compute(sensor, paramsOSDec);
    adaptedOSDec = osLinearCompute(adaptedOSDec, sensor);
    % adaptedOs.plotResults(sensor)
    
    osAdaptedCur = osLinearGet(adaptedOS, 'ConeCurrentSignal');

    % summary stats
    MaxInc(step) = adaptedCurInc(1, 1, stimPeriod(2)-1) - adaptedCurInc(1, 1, stimPeriod(1)-1);
    MaxDec(step) = adaptedCurDec(1, 1, stimPeriod(2)-1) - adaptedCurDec(1, 1, stimPeriod(1)-1);
    
    MaxOSInc(step) = adaptedOSInc.ConeCurrentSignal(1, 1, stimPeriod(2)-1) - adaptedOSInc.ConeCurrentSignal(1, 1, stimPeriod(1)-1);
    MaxOSDec(step) = adaptedOSDec.ConeCurrentSignal(1, 1, stimPeriod(2)-1) - adaptedOSDec.ConeCurrentSignal(1, 1, stimPeriod(1)-1);
    
    % plot
    subplot(1,2,1);
    plot((1:nSamples)*timeStep, adaptedCurInc(:), (1:nSamples)*timeStep, adaptedCurDec(:));
    pause(0.1);
    
    subplot(1,2,2);
    plot((1:nSamples)*timeStep, adaptedOSInc.ConeCurrentSignal(:), (1:nSamples)*timeStep, adaptedOSDec.ConeCurrentSignal(:));
    pause(0.1);
end

subplot(1,2,1); title('coneAdapt');
subplot(1,2,2); title('osBioPhys');
    
figure(2); 
clf
% subplot(1,2,1);
semilogx(stimIntensity, -MaxDec ./ MaxInc, 'ro');
xlabel('background');
ylabel('dec/inc');
title('coneAdapt');

% subplot(1,2,2);
hold on;
semilogx(stimIntensity, -MaxOSDec ./ MaxOSInc, 'kx');
xlabel('background');
ylabel('dec/inc');
% title('osBioPhys');
legend('coneAdapt','osLinear');

tolerance = 1e-12;
UnitTest.assertIsZero(max(abs((-MaxDec ./ MaxInc)-(-MaxOSDec ./ MaxOSInc))),'Comparison for dark impulse response',tolerance);
UnitTest.validationData('adaptedCur',adaptedCur);
UnitTest.validationData('osAdaptedCur',osAdaptedCur);


%figure; scatter(adaptedCur(:), adaptedOS.ConeCurrentSignal(:));

end
