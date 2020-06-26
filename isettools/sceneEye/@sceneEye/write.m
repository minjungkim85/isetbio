function objNew = write(obj, varargin)
% Used by sceneEye.render. Typically not called directly.
%
% Syntax:
%   objNew = write(obj, [varargin])
%
% Description:
%	 A sceneEye object, has all the information needed to construct a PBRT
%	 file and render it. This function reads and interprets the parameters
%	 given in the sceneEye object and writes them out into an PBRT file.
%	 This file will later be rendered in sceneEye.render.
%
%    Copies the sceneEye parameters into the recipe and then writes out the
%    PBRT file. Typically a user will not run this directly, but rather it
%    will be run within the render function.
%
% Inputs:
%    obj   - Object. The scene3D object to render.
%
% Outputs:
%   objNew - Object. The object may have been modified in the processing
%            below. We return this modified version.
%
% Optional key/value pairs:
%    N/A
%
% See also
%   piWrite

%% PROGRAMMING TODO
%
%  This function should be using thisR.set/get not direct writes into the
%  recipe.
%
%  It seems to me also that this function copies the parameters in the
%  sceneEye object into the recipe object.  That is what a lot of the
%  sets/gets are about.  It then calls piWrite with the 'recipe'.  I am not
%  sure why sceneEye doesn't just manage the recipe directly, rather than
%  duplicating the parameters.
%

%% Make a copy of the current object
% We will render this copy, since we may make changes to certain parameters
% before rendering (i.e. in th eccentricity calculations) but we don't want
% these changes to show up original object given by the user.
objNew = copy(obj);
objNew.recipe = copy(obj.recipe);

%% Make some eccentricity calculations
% To render an image centered at a certain eccentricity without having
% change PBRT, we do the following:
% 1. Change the film size and resolution so that renders a larger image
%    that encompasses the desired eccentricity (tempWidth/tempHeight)
% 2. Insert a "crop window" PBRT parameter to only render the window
%    centered at the desired eccentricity with the desired film
%    diagonal/resolution.
ecc = objNew.eccentricity;

% I was having many bugs with my eccentricity code, so for now I've removed
% it for now. Ideally we do all the right calculations shown above and then
% use scene3d.recipe.set('cropwindow', [x1 x2 y1 y2]); and then carefully
% reset the angular support as well...
if(ecc ~= [0, 0])
    warning('Eccentricity is currently not implemented. Setting to zero.')
    ecc = [0 0];
end

%% Given the sceneEye object, make all adjustments needed to the recipe
recipe = objNew.recipe;

% Depending on the eye model, set the lens file appropriately
switch ieParamFormat(objNew.modelName)
    case {'navarro'}
        % Apply any accommodation changes
        if(isempty(objNew.accommodation))
            objNew.accommodation = 5;
            warning('No accommodation! Setting to 5 diopters.');
        end

        % This function also writes out the Navarro lens file
        recipe = setNavarroAccommodation(recipe, objNew.accommodation, ...
            objNew.workingDir);

    case {'legrand'}
        % Le Grand eye does not have accommodation (not yet at least).
        recipe = writeLegrandLensFile(recipe, objNew.workingDir); 

    case{'arizona'}
        if(isempty(objNew.accommodation))
            objNew.accommodation = 5;
            warning('No accommodation! Setting to 5 diopters.');
        end

        % This function also writes out the Arizona lens file.
        recipe = setArizonaAccommodation(recipe, objNew.accommodation, ...
            objNew.workingDir);

    case{'custom'}
        
        % Run this first to generate the IOR files.
        setNavarroAccommodation(recipe, 0, objNew.workingDir);

        % Copy the lens file given over
        if(isempty(obj.lensFile))
            error('No lens file given for custom eye.')
        else
            % Copy lens file over to the working directory and then attach
            % to recipe
            [success, message] = copyfile(obj.lensFile, objNew.workingDir);
            [~, n, e] = fileparts(obj.lensFile);

            if(success)
                recipe.camera.lensfile.value = ...
                    fullfile(objNew.workingDir, [n e]);
                recipe.camera.lensfile.type = 'string';
            else
                error('Error copying lens file. Err message: %s', message);
            end
        end

end

% Film parameters
recipe.film.xresolution.value = objNew.resolution;
recipe.film.yresolution.value = objNew.resolution;

% Camera parameters
if(objNew.debugMode)
    % Use a perspective camera with matching FOV instead of an eye.
    fov = struct('value', objNew.fov, 'type', 'float');
    recipe.camera = struct('type', 'Camera', 'subtype', 'perspective', ...
        'fov', fov);
    if(objNew.accommodation ~= 0)
        warning(['Setting perspective camera focal distance to %0.2f ' ...
            'dpt and lens radius to %0.2f mm'], ...
            objNew.accommodation, objNew.pupilDiameter);
        recipe.camera.focaldistance.value = 1/objNew.accommodation;
        recipe.camera.focaldistance.type = 'float';

        recipe.camera.lensradius.value = ...
            (objNew.pupilDiameter / 2) * 10 ^ -3;
        recipe.camera.lensradius.type = 'float';
    end
else
    recipe.camera.retinaDistance.value = objNew.retinaDistance;
    recipe.camera.pupilDiameter.value = objNew.pupilDiameter;
    recipe.camera.retinaDistance.value = objNew.retinaDistance;
    recipe.camera.retinaRadius.value = objNew.retinaRadius;
    recipe.camera.retinaSemiDiam.value = objNew.retinaDistance * ...
        tand(objNew.fov / 2);
    if(strcmp(objNew.sceneUnits, 'm'))
        recipe.camera.mmUnits.value = 'false';
        recipe.camera.mmUnits.type = 'bool';
    end
    if(objNew.diffractionEnabled)
        recipe.camera.diffractionEnabled.value = 'true';
        recipe.camera.diffractionEnabled.type = 'bool';
    end
end

% Sampler
recipe.sampler.pixelsamples.value = objNew.numRays;

% Integrator
recipe.integrator.maxdepth.value = objNew.numBounces;
recipe.integrator.maxdepth.type = 'integer';

% Renderer
if(objNew.numCABands == 0 || objNew.numCABands == 1 || objNew.debugMode)
    % No spectral rendering
    recipe.integrator.subtype = 'path';
else
    % Spectral rendering
    numCABands = struct('value', objNew.numCABands, 'type', 'integer');
    recipe.integrator = struct('type', 'Integrator', ...
        'subtype', 'spectralpath', 'numCABands', numCABands);
end

% Look At
if(isempty(objNew.eyePos) || isempty(objNew.eyeTo) || ...
        isempty(objNew.eyeUp))
    error('Eye location missing!');
else
    recipe.lookAt = struct('from', objNew.eyePos, 'to', objNew.eyeTo, ...
        'up', objNew.eyeUp);
end

% If there was a crop window, we have to update the angular support that
% comes with sceneEye
% We can't do this right now because the angular support is a dependent
% variable. How to overcome this?
%{
currAngSupport = obj.angularSupport;
cropWindow = recipe.get('cropwindow');
cropWindowR = cropWindow.*obj.resolution;
cropWindowR = [cropWindowR(1) cropWindowR(3) ...
    cropWindowR(2)-cropWindowR(1) cropWindowR(4)-cropWindowR(3)];
[X, Y] = meshgrid(currAngSupport, currAngSupport);
X = imcrop(X, cropWindowR);
Y = imcrop(Y, cropWindowR);
% Assume square optical image for now, but we should probably change
% angularSupport to have both x and y direction.
objNew.angularSupport = X(1, :); 
%}

%% Write out the adjusted recipe into a PBRT file
pbrtFile = fullfile(objNew.workingDir, strcat(objNew.name, '.pbrt'));
recipe.set('outputFile', pbrtFile);
if(strcmp(recipe.exporter, 'C4D'))
    piWrite(recipe, 'overwritepbrtfile', true, ...
        'overwritelensfile', false, 'overwriteresources', false, ...
        'creatematerials', true);
else
    piWrite(recipe, 'overwritepbrtfile', true, ...
        'overwritelensfile', false, 'overwriteresources', false);
end
obj.recipe = recipe; % Update the recipe.

end
