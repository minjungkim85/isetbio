% t_rgcSubunit
% 
% Demonstrates the inner retina object calculation for the subunit RGC
% model (related to Meister).
% 
% 3/2016 BW JRG HJ (c) isetbio team

%%
ieInit

%% Movie of the cone absorptions 

% Get data from isetbio archiva server
rd = RdtClient('isetbio');
rd.crp('/resources/data/istim');
a = rd.listArtifacts;

% Pull out .mat data from artifact
whichA =1 ;
thisStimulus = a(whichA).artifactId;
data = rd.readArtifact(a(whichA).artifactId);
% iStim stores the scene, oi and cone absorptions
iStim = data.iStim;
absorptions = iStim.absorptions;
absorptions = sensorSet(absorptions,'name',thisStimulus);

%% Show raw stimulus for osIdentity
vcNewGraphWin;
for frame1 = 1:size(iStim.sceneRGB,3)
    imagesc(squeeze(iStim.sceneRGB(:,:,frame1,:)));
    colormap gray; drawnow;
end
close;

%% Outer segment calculation
% 
% Input = RGB
osI = osCreate('identity');

% Set size of retinal patch
patchSize = sensorGet(absorptions,'width','um');
osI = osSet(osI, 'patch size', patchSize);

% Set time step of simulation equal to absorptions
timeStep = sensorGet(absorptions,'time interval','sec');
osI = osSet(osI, 'time step', timeStep);

% Set osI data to raw pixel intensities of stimulus
osI = osSet(osI, 'rgbData', iStim.sceneRGB);
% os = osCompute(sensor);

% % Plot the photocurrent for a pixel
% osPlot(osI,absorptions);
%% Build the inner retina object with a subunit mosaic

clear params
params.name      = 'Macaque inner retina 1'; % This instance
params.eyeSide   = 'left';   % Which eye
params.eyeRadius = 4;        % Radius in mm
params.eyeAngle  = 90;       % Polar angle in degrees

innerRetina0 = irCreate(osI, params);

% Create a subunit model for the on midget ganglion cell parameters
innerRetina0.mosaicCreate('model','subunit','type','on midget');
irPlot(innerRetina0,'mosaic');

%% Compute RGC mosaic responses

innerRetina0 = irCompute(innerRetina0, osI);
irPlot(innerRetina0, 'psth');
% irPlot(innerRetina0, 'linear');
% irPlot(innerRetina0, 'raster');

%% Show stimulus over cone mosaic for osLinear, osBioPhys
vcNewGraphWin;
coneImageActivity(absorptions,'step',1,'dFlag',true);
%% Compute the outer segment response

% In this case we use a linear model.  Below we use a more complex model
osL = osCreate('linear');

% Set up the 
patchSize = sensorGet(absorptions,'width','um');
osL = osSet(osL, 'patch size', patchSize);

timeStep = sensorGet(absorptions,'time interval','sec');
osL = osSet(osL, 'time step', timeStep);

osL = osCompute(osL, absorptions);

%% Build the inner retina object

clear params
params.name      = 'Macaque inner retina 1'; % This instance
params.eyeSide   = 'left';   % Which eye
params.eyeRadius = 4;        % Radius in mm
params.eyeAngle  = 90;       % Polar angle in degrees

innerRetina1 = irCreate(osL, params);

% Create a coupled GLM model for the on midget ganglion cell parameters
innerRetina1.mosaicCreate('model','glm','type','on midget');


%% Compute RGC mosaic responses

innerRetina1 = irCompute(innerRetina1, osL);
irPlot(innerRetina1, 'psth');

%% Show me the PSTH for one particular cell

irPlot(innerRetina1, 'psth response','cell',[2 2]);
title('OS Linear and Coupled GLM');

%% Compute the outer segment response

% In this case we use a linear model.  Below we use a more complex model
osB = osCreate('bioPhys');

% Set up the 
patchSize = sensorGet(absorptions,'width','um');
osB = osSet(osB, 'patch size', patchSize);

timeStep = sensorGet(absorptions,'time interval','sec');
osB = osSet(osB, 'time step', timeStep);

osB = osCompute(osB, absorptions);

%% Compute RGC mosaic responses

innerRetina2 = irCreate(osB, params);
innerRetina2.mosaicCreate('model','glm','type','on midget');

innerRetina2 = irCompute(innerRetina2, osB);
irPlot(innerRetina2, 'psth response');

%% Show me the PSTH for one particular cell

irPlot(innerRetina2, 'psth response','cell',[2 2]);
title('OS Biophys and Coupled GLM');

%%

irPlot(innerRetina2, 'raster','cell',[1 1]);