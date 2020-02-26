function unitTestSmoothGrid()

    % Options
    loadHistory = ~true;
    visualizeProgress = loadHistory;

    
    % Size of mosaic to generate
    mosaicFOVDegs  = 20; 
    
    % Samples of eccentricities to tabulate spacing on
    % Precompute cone spacing for a grid of [eccentricitySamplesNum x eccentricitySamplesNum] covering the range of conePositions
    eccentricitySamplesNum = 32;
    
    % Which eye
    whichEye = 'right';
    
    
    % Termination conditions
    % 1. Stop if cones move less than this positional tolerance (x 2) in microns
    dTolerance = 1.0e-3;
    
    % 2. Stop if we exceed this many iterations
    maxIterations = 3000;
    
    % 3. Trigger Delayun triangularization if come movements (x 2 microns) for triggering a Delayun triangularization
    percentageConeSeparationPositionalThreshold = 99;
    
    % 4. Do not trigger Delayun triangularization if less than minIterationsBeforeRetriangulation have passed since last one
    minIterationsBeforeRetriangulation = 5;
    
    % 5. Trigger Delayun triangularization if more than maxIterationsBeforeRetriangulation have passed since last one
    maxIterationsBeforeRetriangulation = 15;
    
    % 6. Interval to query user whether he/she wants to terminate
    queryUserIntervalMinutes = 90;
    
    % Save filename
    p = getpref('IBIOColorDetect');
    coneLocsDir = strrep(p.validationRootDir, 'validations', 'sideprojects/MosaicGenerator'); 
    saveFileName = fullfile(coneLocsDir, sprintf('progress_%sMosaic%2.1fdegs_samplesNum%d_prctile%d.mat', whichEye, mosaicFOVDegs, eccentricitySamplesNum, percentageConeSeparationPositionalThreshold));

    % Set grid params
    gridParams.coneSpacingFunctionFull = @coneSpacingFunctionFull;
    gridParams.coneSpacingFunctionFast = @coneSpacingFunctionFast;
    gridParams.domainFunction = @ellipticalDomainFunction;
    
    gridParams.center = [0 0];
    gridParams.ellipseAxes = [1 1.2247];
    gridParams.borderTolerance = 0.001 * 2;
    gridParams.lambdaMin = 2;
    gridParams.dTolerance = gridParams.lambdaMin * dTolerance;
    gridParams.rng = 1;
    
   
    if (loadHistory)
        load(saveFileName, 'conePositionsHistory','iterationsHistory', 'maxMovements', 'reTriangulationIterations', 'terminationReason');
        fprintf('Termination reason for this mosaic: %s\n', terminationReason)
        hFig = figure(1); clf;
        set(hFig, 'Position', [10 10 1596 1076]);
        generateMosaicProgressVideo(strrep(saveFileName, 'progress', 'video'), hFig , conePositionsHistory, iterationsHistory, maxMovements, reTriangulationIterations, gridParams.dTolerance, mosaicFOVDegs);
        return;
    end
    
    % Generate cone positions and downsample according to the density
    tStart = tic;
    conePositions = generateConePositions(mosaicFOVDegs*1.07);
    [conePositions, gridParams] = downSampleConePositions(conePositions, gridParams, percentageConeSeparationPositionalThreshold, tStart);
       
    
    conesNum = size(conePositions,1);
    if (conesNum > 1000*1000)
        fprintf('Iteration: 0, Adusting %2.1f million cones, time lapsed: %f minutes\n', size(conePositions,1)/1000000, toc(tStart)/60);
    else
        fprintf('Iteration: 0, Adusting %2.1f thousand cones, time lapsed: %f minutes\n', size(conePositions,1)/1000, toc(tStart)/60);
    end
    
    % Tabulate ecc
    [tabulatedEccXYMicrons, tabulatedConeSpacingInMicrons] = ...
            computeTableOfConeSpacings(conePositions, eccentricitySamplesNum, whichEye);
    
    % Do it
    [conePositions, conePositionsHistory,iterationsHistory, maxMovements, reTriangulationIterations, terminationReason] = ...
        smoothGrid(gridParams, conePositions,  minIterationsBeforeRetriangulation, maxIterationsBeforeRetriangulation, maxIterations, queryUserIntervalMinutes, ...
        visualizeProgress,  tabulatedEccXYMicrons, tabulatedConeSpacingInMicrons,  mosaicFOVDegs, tStart);        
    
    % Save results
    save(saveFileName, 'conePositions', 'conePositionsHistory', 'iterationsHistory', 'maxMovements', 'reTriangulationIterations', ...
        'terminationReason', 'tabulatedEccXYMicrons', 'tabulatedConeSpacingInMicrons', ...
        '-v7.3');
    fprintf('History saved  in %s\n', saveFileName);
end

function [conePositions, gridParams] = downSampleConePositions(conePositions, gridParams, percentageConeSeparationPositionalThreshold, tStart)
    
    rng(gridParams.rng);
    
    conesNum = size(conePositions,1);
    if (conesNum > 1000*1000)
        fprintf('Started with %2.1f million cones, time lapsed: %f minutes\n', conesNum/1000000, toc(tStart)/60);
    else
        fprintf('Started with %2.1f thousand cones, time lapsed: %f minutes\n', conesNum/1000, toc(tStart)/60);
    end

    fprintf('Removing cones outside the ellipse ...');
    gridParams.radius = max(abs(conePositions(:)));

    % Remove cones outside the desired region by applying the provided
    % domain function
    d = feval(gridParams.domainFunction, conePositions, ...
        gridParams.center, gridParams.radius, gridParams.ellipseAxes);
    conePositions = conePositions(d < gridParams.borderTolerance, :);
    fprintf('... time lapsed: %f minutes.\n', toc(tStart)/60);


    % sample probabilistically according to coneSpacingFunction
    conesNum = size(conePositions,1);
    if (conesNum > 1000*1000)
        fprintf('Computing separations for %2.1f million cones ...', conesNum/1000000);
    else
        fprintf('Computing separations for %2.1f thousand cones ...', conesNum/1000);
    end
    coneSeparations = feval(gridParams.coneSpacingFunctionFull, conePositions);
    gridParams.positionalDiffTolerance = prctile(coneSeparations,percentageConeSeparationPositionalThreshold);

    fprintf('... time lapsed: %f minutes.',  toc(tStart)/60);

    fprintf('\nProbabilistic sampling ...');
    normalizedConeSeparations = coneSeparations / gridParams.lambdaMin;
    densityP = 1/(sqrt(2/3)) * (1 ./ normalizedConeSeparations) .^ 2;

    % Remove cones accordingly
    fixedConePositionsRadiusInCones = 1;
    radii = sqrt(sum(conePositions.^2,2));

    keptConeIndices = find(...
        (rand(size(conePositions, 1), 1) < densityP) | ...
        ((radii < fixedConePositionsRadiusInCones*gridParams.lambdaMin)) );

    conePositions = conePositions(keptConeIndices, :);
    fprintf(' ... done ! After %f minutes.\n', toc(tStart)/60);
end
    
function conePositions = generateConePositions(fovDegs)
    micronsPerDeg = 300;
    radius = fovDegs/2*1.2*micronsPerDeg;
    lambda = 2;
    rows = 2 * radius;
    cols = rows;
    conePositions = computeHexGrid(rows, cols, lambda);
end

function hexLocs = computeHexGrid(rows, cols, lambda)
    scaleF = sqrt(3) / 2;
    extraCols = round(cols / scaleF) - cols;
    rectXaxis2 = (1:(cols + extraCols));
    [X2, Y2] = meshgrid(rectXaxis2, 1:rows);

    X2 = X2 * scaleF ;
    for iCol = 1:size(Y2, 2)
        Y2(:, iCol) = Y2(:, iCol) - mod(iCol - 1, 2) * 0.5;
    end

    % Scale to get correct density
    X2 = X2 * lambda;
    Y2 = Y2 * lambda;
    marginInConePositions = 0.1;
    indicesToKeep = (X2 >= -marginInConePositions) & ...
                    (X2 <= cols+marginInConePositions) &...
                    (Y2 >= -marginInConePositions) & ...
                    (Y2 <= rows+marginInConePositions);
    xHex = X2(indicesToKeep);
    yHex = Y2(indicesToKeep);
    hexLocs = [xHex(:) - mean(xHex(:)) yHex(:) - mean(yHex(:))];
end

function [tabulatedEccXYMicrons, tabulatedConeSpacingInMicrons] = computeTableOfConeSpacings(conePositions, eccentricitySamplesNum, whichEye)
        eccentricitiesInMeters = sqrt(sum(conePositions .^ 2, 2)) * 1e-6;
        s = sort(eccentricitiesInMeters);
        maxConePositionMeters = max(s);
        minConePositionMeters = min(s(s>0));
        eccentricitiesInMeters = logspace(log10(minConePositionMeters), log10(maxConePositionMeters), eccentricitySamplesNum);
        tabulatedEccMeters1D = [-fliplr(eccentricitiesInMeters) 0 eccentricitiesInMeters];
        [tabulatedEccX, tabulatedEccY] = meshgrid(tabulatedEccMeters1D);
        tabulatedEccX = tabulatedEccX(:);
        tabulatedEccY = tabulatedEccY(:);
        
        tabulatedEccMeters = sqrt(tabulatedEccX.^2 + tabulatedEccY.^2);
        tabulatedEccAngles = atan2d(tabulatedEccY, tabulatedEccX);
        tabulatedConeSpacingInMeters = coneSizeReadData(...
            'eccentricity', tabulatedEccMeters, ...
            'angle', tabulatedEccAngles, ...
            'whichEye', whichEye);

        tabulatedEccXYMicrons = [tabulatedEccX tabulatedEccY]*1e6;
        tabulatedConeSpacingInMicrons = tabulatedConeSpacingInMeters * 1e6;
        
        % In ConeSizeReadData, spacing is computed as sqrt(1/density). This is
        % true for a rectangular mosaic. For a hex mosaic, spacing = sqrt(2.0/(3*density)).
        tabulatedConeSpacingInMicrons = sqrt(2/3)*tabulatedConeSpacingInMicrons;
end
    
function [conePositions, conePositionsHistory, iterationsHistory, maxMovements, reTriangulationIterations, terminationReason] = ...
    smoothGrid(gridParams, conePositions,  minIterationsBeforeRetriangulation, maxIterationsBeforeRetriangulation, maxIterations, queryUserIntervalMinutes, ...
    visualizeProgress, tabulatedEccXYMicrons, tabulatedConeSpacingInMicrons, mosaicFOVDegs, tStart)  

    gridParams.maxIterations = maxIterations;
    deps = sqrt(eps) * gridParams.lambdaMin;
    deltaT = 0.2;

    % Initialize convergence
    forceMagnitudes = [];

    % Turn off Delaunay triangularization warning
    warning('off', 'MATLAB:qhullmx:InternalWarning');
    
    % Number of cones
    conesNum = size(conePositions, 1);
    
    % Iteratively adjust the cone positions until the forces between nodes
    % (conePositions) reach equilibrium.
    notConverged = true;
    terminateNowDueToReductionInLatticeQuality = false;
    oldConePositions = inf;
    
    iteration = 0;
    maxMovements = [];
    conePositionsHistory = [];
    
    lastTriangularizationAtIteration = iteration;
    minimalIterationsPerformedAfterLastTriangularization = 0;
    histogramWidths = [];
    reTriangulationIterations = [];
    timeLapsedHoursPrevious = [];
    userRequestTerminationAtIteration = [];
    terminateNow = false;
    
    while (~terminateNow) && (~terminateNowDueToReductionInLatticeQuality) && (notConverged) && (iteration <= gridParams.maxIterations) || ...
            ((lastTriangularizationAtIteration > iteration-minimalIterationsPerformedAfterLastTriangularization)&&(iteration > gridParams.maxIterations))
        
        if ((lastTriangularizationAtIteration > iteration-minimalIterationsPerformedAfterLastTriangularization)&&(iteration > gridParams.maxIterations))
            fprintf('Exceed max iterations (%d), but last triangularization was less than %d iterations before so we will do one more iteration\n', gridParams.maxIterations,minimalIterationsPerformedAfterLastTriangularization);
        end
        
        iteration = iteration + 1;

        % compute cone positional diffs
        positionalDiffs = sqrt(sum((conePositions-oldConePositions).^ 2,2)); 
        
        % Check if we need to re-triangulate
        %positionalDiffsMetric = max(positionalDiffs);
        %positionalDiffsMetric = median(positionalDiffs);
        positionalDiffsMetric = prctile(positionalDiffs, 99);
        
        % We need to triangulate again if the positionalDiff is above the set tolerance
        reTriangulationIsNeeded = (positionalDiffsMetric > gridParams.positionalDiffTolerance);
        
        % We need to triangulate again if the movement in the current iteration was > the average movement in the last 2 iterations 
        if (numel(maxMovements)>3) && (maxMovements(iteration-1) > 0.5*(maxMovements(iteration-2)+maxMovements(iteration-3)))
            reTriangulationIsNeeded = true;
        end
        
        % We need to triangulate again if we went for maxIterationsToRetriangulate + some more since last triangularization
        if ((abs(lastTriangularizationAtIteration-iteration-1)) > maxIterationsBeforeRetriangulation+(round(iteration/10)))
            reTriangulationIsNeeded = true;
        end
        
        % Do not triangulare if we did one less than minIterationsBeforeRetriangulation before
        if ((abs(lastTriangularizationAtIteration-iteration-1)) < minIterationsBeforeRetriangulation)
            reTriangulationIsNeeded = false;
        end
        
        %
        if (iteration==1)
            reTriangulationIsNeeded = true;
        end
        
        if (reTriangulationIsNeeded)
            lastTriangularizationAtIteration = iteration;
            % save old come positions
            oldConePositions = conePositions;
            
            % Perform new Delaunay triangulation to determine the updated
            % topology of the truss.
            triangleConeIndices = delaunayn(conePositions);
            % Compute the centroids of all triangles
            centroidPositions = 1.0/3.0 * (...
                    conePositions(triangleConeIndices(:, 1), :) + ...
                    conePositions(triangleConeIndices(:, 2), :) + ...
                    conePositions(triangleConeIndices(:, 3), :));
            
            % Remove centroids outside the desired region by applying the
            % signed distance function
            d = feval(gridParams.domainFunction, centroidPositions, ...
                    gridParams.center, gridParams.radius, ...
                    gridParams.ellipseAxes);
            triangleConeIndices = triangleConeIndices(d < gridParams.borderTolerance, :);
            
           % Create a list of the unique springs (each spring connecting 2 cones)
           springs = [...
                    triangleConeIndices(:, [1, 2]); ...
                    triangleConeIndices(:, [1, 3]); ...
                    triangleConeIndices(:, [2, 3]) ...
           ];
           springs = unique(sort(springs, 2), 'rows');
            
           % find all springs connected to this cone
           springIndices = cell(1,conesNum);
           for coneIndex = 1:conesNum
               springIndices{coneIndex} = find((springs(:, 1) == coneIndex) | (springs(:, 2) == coneIndex));
           end
        end % reTriangulationIsNeeded
        
        % Compute spring vectors
        springVectors =  conePositions(springs(:, 1), :) - conePositions(springs(:, 2), :);
        % their centers
        springCenters = (conePositions(springs(:, 1), :) + conePositions(springs(:, 2), :)) / 2.0;
        % and their lengths
        springLengths = sqrt(sum(springVectors.^2, 2));

        if (reTriangulationIsNeeded)
            % Compute desired spring lengths. This is done by evaluating the
            % passed coneDistance function at the spring centers.
            desiredSpringLengths= feval(gridParams.coneSpacingFunctionFast, springCenters, tabulatedEccXYMicrons, tabulatedConeSpacingInMicrons);
        end
        
        % Normalize spring lengths
        normalizingFactor = sqrt(sum(springLengths .^ 2) / ...
            sum(desiredSpringLengths .^ 2));
        desiredSpringLengths = desiredSpringLengths * normalizingFactor;
        
        gain = 1.1;
        springForces = max(gain * desiredSpringLengths - springLengths, 0);

        % compute x, y-components of forces on each of the springs
        springForceXYcomponents = abs(springForces ./ springLengths * [1, 1] .* springVectors);

        % Compute net forces on each cone
        netForceVectors = zeros(conesNum, 2);
        
        parfor coneIndex = 1:conesNum
           % compute net force from all connected springs
           deltaPos = -bsxfun(@minus, springCenters(springIndices{coneIndex}, :), conePositions(coneIndex, :));
           netForceVectors(coneIndex, :) = sum(sign(deltaPos) .* springForceXYcomponents(springIndices{coneIndex}, :), 1);
        end
            
        % update cone positions according to netForceVectors
        conePositions = conePositions + deltaT * netForceVectors;
        
        d = feval(gridParams.domainFunction, conePositions, ...
                gridParams.center, gridParams.radius, gridParams.ellipseAxes);
        outsideBoundaryIndices = d > 0;
            
        % And project them back to the domain
        if (~isempty(outsideBoundaryIndices))
                % Compute numerical gradient along x-positions
                dXgradient = (feval(gridParams.domainFunction, ...
                    [conePositions(outsideBoundaryIndices, 1) + deps, ...
                    conePositions(outsideBoundaryIndices, 2)], ...
                    gridParams.center, gridParams.radius, ...
                    gridParams.ellipseAxes) - d(outsideBoundaryIndices)) / ...
                    deps;
                dYgradient = (feval(gridParams.domainFunction, ...
                    [conePositions(outsideBoundaryIndices, 1), ...
                    conePositions(outsideBoundaryIndices, 2)+deps], ...
                    gridParams.center, gridParams.radius, ...
                    gridParams.ellipseAxes) - d(outsideBoundaryIndices)) / ...
                    deps;

                % Project these points back to boundary
                conePositions(outsideBoundaryIndices, :) = ...
                    conePositions(outsideBoundaryIndices, :) - ...
                    [d(outsideBoundaryIndices) .* dXgradient, ...
                    d(outsideBoundaryIndices) .* dYgradient];
        end
            
        % Check if all interior nodes move less than dTolerance
        movementAmplitudes = sqrt(sum(deltaT * netForceVectors(d < -gridParams.borderTolerance, :) .^2 , 2));
        maxMovement = prctile(movementAmplitudes, 50);
        maxMovements(iteration) = maxMovement;
        
        if maxMovement < gridParams.dTolerance
            notConverged = false; 
        end
          
        % Check for early termination due to decrease in hex lattice quality
        if (reTriangulationIsNeeded)
            reTriangulationIterations = cat(2,reTriangulationIterations, iteration);
            [terminateNowDueToReductionInLatticeQuality, histogramData, histogramWidths, histogramDiffWidths, checkedBins] = ...
                checkForEarlyTerminationDueToHexLatticeQualityDecrease(conePositions, triangleConeIndices, histogramWidths);
        end
        
        if  ( reTriangulationIsNeeded || terminateNowDueToReductionInLatticeQuality)  
            % See if another hour passed and asked the used whether to
            % terminate soon
            timeLapsedMinutes = toc(tStart)/60;
            if (isempty(timeLapsedHoursPrevious))
                timeLapsedHoursPrevious = 0;
            end
            
            timeLapsedHours = floor(timeLapsedMinutes/queryUserIntervalMinutes);
            
            if (timeLapsedHours > timeLapsedHoursPrevious)
                queryUserWhetherToTerminateSoon = true;
            else
                queryUserWhetherToTerminateSoon = false;
            end
            timeLapsedHoursPrevious = timeLapsedHours;
            
            fprintf('\t>Iteration: %d/%d, medianMov: %2.6f, tolerance: %2.3f, time lapsed: %f minutes\n', ...
                iteration, gridParams.maxIterations, maxMovement, gridParams.dTolerance, timeLapsedMinutes);
            
            if (isempty(conePositionsHistory))
                conePositionsHistory(1,:,:) = single(conePositions);
                iterationsHistory = iteration;
            else
                conePositionsHistory = cat(1, conePositionsHistory, reshape(single(conePositions), [1 size(conePositions,1) size(conePositions,2)]));
                iterationsHistory = cat(2, iterationsHistory, iteration);
            end
            
            if (visualizeProgress)
                plotMosaic([], conePositions, triangleConeIndices, maxMovements, reTriangulationIterations, histogramDiffWidths, histogramData, checkedBins, gridParams.dTolerance, mosaicFOVDegs);
            else
                plotMovementSequence([],maxMovements, gridParams.dTolerance)
                plotMeshQuality([],histogramData, checkedBins, iterationsHistory);
            end
        end
        
        if (queryUserWhetherToTerminateSoon)
            fprintf('Another %d minute period has passed. Terminate soon?', queryUserIntervalMinutes);
            userTermination = GetWithDefault(' If so enter # of iteration to terminate on. Otherwise hit enter to continue', 'continue');
            if (~strcmp(userTermination, 'continue'))
                userRequestTerminationAtIteration = str2double(userTermination);
                if (isnan(userRequestTerminationAtIteration))
                    userRequestTerminationAtIteration = [];
                end
            else
                fprintf('OK, will ask again in %d minutes.', queryUserIntervalMinutes);
            end
        end
        queryUserWhetherToTerminateSoon = false;
        
        
        if (terminateNowDueToReductionInLatticeQuality)
            % Return the last cone positions
            conePositions = conePositionsLast;
        else
            % Save last conePositions
            conePositionsLast = conePositions;
        end
        
        if (~isempty(userRequestTerminationAtIteration)) && (iteration >= userRequestTerminationAtIteration)
            conePositionsHistory = cat(1, conePositionsHistory, reshape(single(conePositions), [1 size(conePositions,1) size(conePositions,2)]));
            iterationsHistory = cat(2, iterationsHistory, iteration);
            reTriangulationIterations = cat(2,reTriangulationIterations, iteration);
            fprintf('Current iteration: %d, user request stop iteration: %d\n', iteration,userRequestTerminationAtIteration)
            terminateNow = true;
        end
        
    end
    
    if (terminateNow)
            terminationReason = sprintf('User requested termination at iteration %d', userRequestTerminationAtIteration);
    else
        if (notConverged)
            if (terminateNowDueToReductionInLatticeQuality)
                terminationReason = 'Decrease in hex lattice quality.';
            else
                terminationReason = 'Exceeded max number of iterations.';
            end
        else
            terminationReason = 'Converged.';
        end
    end
    
    fprintf('Hex lattice adjustment ended. Reason: %s\n', terminationReason);
end

function distances = ellipticalDomainFunction(conePositions, center, radius, ellipseAxes)
    xx = conePositions(:, 1) - center(1);
    yy = conePositions(:, 2) - center(2);
    radii = sqrt((xx / ellipseAxes(1)) .^ 2 + (yy / ellipseAxes(2)) .^ 2);
    distances = radii - radius;
end

function [coneSpacingInMicrons, eccentricitiesInMicrons] = coneSpacingFunctionFull(conePositions)
    eccentricitiesInMicrons = sqrt(sum(conePositions .^ 2, 2));
    eccentricitiesInMeters = eccentricitiesInMicrons * 1e-6;
    angles = atan2(conePositions(:, 2), conePositions(:, 1)) / pi * 180;
    coneSpacingInMeters = coneSizeReadData('eccentricity', eccentricitiesInMeters, 'angle', angles);
    coneSpacingInMicrons = coneSpacingInMeters' * 1e6;
end

function coneSpacingInMicrons = coneSpacingFunctionFast(conePositions, tabulatedEccXYMicrons, tabulatedConeSpacingInMicrons)
    [~, I] = pdist2(tabulatedEccXYMicrons, conePositions, 'euclidean', 'Smallest', 1);
    coneSpacingInMicrons = (tabulatedConeSpacingInMicrons(I))';
end

function generateMosaicProgressVideo(videoFileName, hFigVideo, conePositionsHistory, iterationsHistory, maxMovements, reTriangulationIterations, dTolerance, mosaicFOVDegs)
    videoOBJ = VideoWriter(videoFileName, 'MPEG-4'); % H264 format
    videoOBJ.FrameRate = 30;
    videoOBJ.Quality = 100;
    videoOBJ.open();
    
    widths = [];
    for k = 1:size(conePositionsHistory,1)
        currentConePositions = squeeze(conePositionsHistory(k,:,:));
        triangleConeIndices = delaunayn(double(currentConePositions));
        [~, histogramData, widths, diffWidths, checkedBins] = checkForEarlyTerminationDueToHexLatticeQualityDecrease(currentConePositions, triangleConeIndices, widths);
        plotMosaic(hFigVideo, currentConePositions, triangleConeIndices, maxMovements(1:iterationsHistory(k)), reTriangulationIterations(1:k), diffWidths, histogramData, checkedBins, dTolerance, mosaicFOVDegs);
        % Add video frame
        videoOBJ.writeVideo(getframe(hFigVideo));
    end
    
end

function [terminateNow, histogramData, widths, diffWidths, bin1Percent] = checkForEarlyTerminationDueToHexLatticeQualityDecrease(currentConePositions, triangleConeIndices, widths)
    
    qDist = computeQuality(currentConePositions, triangleConeIndices);
    qBins = [0.5:0.01:1.0];
    [counts,centers] = hist(qDist, qBins);
    bin1Percent = prctile(qDist,[0.8 3 7 15 99.8]);
    [~, idx1] = min(abs(centers-bin1Percent(2)));
    [~, idx2] = min(abs(centers-bin1Percent(3)));
    [~, idx3] = min(abs(centers-bin1Percent(4)));
    [~, idxEnd] = min(abs(centers-bin1Percent(end)));
    if (isempty(widths))
        k = 1;
    else
        k = size(widths,1)+1;
    end
    widths(k,:) = centers(idxEnd)-[centers(idx1) centers(idx2) centers(idx3)];
    if (k == 1)
        diffWidths = nan;
    else
        diffWidths = diff(widths,1)./(widths(end,:));
    end

    histogramData.x = centers;
    histogramData.y = counts;

    % Termination condition
    cond1 = bin1Percent(1) > 0.85;
    cond2 = (any(diffWidths(:) > 0.05)) && (~any((isnan(diffWidths(:)))));
    if (cond1 && cond2)
        fprintf(2,'Should terminate here\n');
        terminateNow = true;
    else
        terminateNow = false;
    end
        
end

function plotMeshQuality(figNo,histogramData, bin1Percent, iterationsHistory)
    if (isempty(figNo))
        figure(10); 
        subplotIndex = mod(numel(iterationsHistory)-1,12)+1;
        if (subplotIndex == 1)
            clf;
        end
        subplot(4,3,subplotIndex);
    end
 
    qLims = [0.6 1.005]; 
    bar(histogramData.x,histogramData.y,1); hold on;
    plot(bin1Percent(1)*[1 1], [0 max(histogramData.y)], 'r-', 'LineWidth', 1.5);
    plot(bin1Percent(end)*[1 1], [0 max(histogramData.y)], 'c-', 'LineWidth', 1.5);
    plot(bin1Percent(2)*[1 1], [0 max(histogramData.y)], 'k-',  'LineWidth', 1.5);
    plot(bin1Percent(3)*[1 1], [0 max(histogramData.y)], 'k-', 'LineWidth', 1.5);
    plot(bin1Percent(4)*[1 1], [0 max(histogramData.y)], 'k-', 'LineWidth', 1.5);
    set(gca, 'XLim', qLims, 'YLim', [0 max(histogramData.y)], 'XTick', [0.1:0.05:1.0],  'FontSize', 16);
    grid on
    xlabel('hex-index $\left(\displaystyle 2 r_{ins} / r_{cir} \right)$', 'Interpreter', 'latex', 'FontSize', 16);
    ylabel('count', 'FontSize', 16);
    if (isempty(figNo))
        title(sprintf('iteration:%d', iterationsHistory(end)))
        drawnow;
    end
    
    if (isempty(figNo))
        figure(11); hold on;
    end
    
end

function plotMovementSequence(figNo, maxMovements, dTolerance)
    if (isempty(figNo))
        figure(11); clf;
    end
    
    if (numel(maxMovements) < 10) 
        markerSize = 12;
    elseif (numel(maxMovements) < 50)
        markerSize = 10;
    elseif (numel(maxMovements) < 100)
        markerSize = 8;
    elseif (numel(maxMovements) < 500)
        markerSize = 6;
    else
        markerSize = 4;
    end
    
    plot(1:numel(maxMovements), maxMovements, 'ko-', 'MarkerFaceColor', [0.7 0.7 0.7], 'MarkerSize', markerSize);
    hold on;
    plot([1 numel(maxMovements)], dTolerance*[1 1], 'r-', 'LineWidth', 1.5);
    set(gca, 'YLim', [dTolerance*0.5 max(maxMovements)], 'YScale', 'log', 'FontSize', 16);
    xlabel('iteration');
    ylabel('median movement', 'FontSize', 16)
end


function plotMosaic(hFig, conePositions, triangleConeIndices, maxMovements,  reTriangulationIterations, widths, histogramData, bin1Percent,  dTolerance, mosaicFOVDegs)

    eccDegs = (sqrt(sum(conePositions.^2, 2)))/300;
    idx = find(eccDegs <= min([1 mosaicFOVDegs])/2);
    %idx = 1:size(conePositions,1);
    
    if (isempty(hFig))
        hFig = figure(1);
        set(hFig, 'Position', [10 10 1596 1076]);
    end
    
    clf;
    subplot(2,3,[1 2 4 5]);
    plotTriangularizationGrid = true;
    if (plotTriangularizationGrid)
        visualizeLatticeState(conePositions, triangleConeIndices);
    end

    plot(conePositions(idx,1), conePositions(idx,2), 'r.');
    maxPos = max(max(abs(conePositions(idx,:))));
    set(gca, 'XLim', maxPos*[-1 1], 'YLim', maxPos*[-1 1], 'FontSize', 16);
    axis 'square'
    
   
    
    subplot(2,3,3);
    yyaxis left
    plotMovementSequence(hFig, maxMovements, dTolerance);
    
    yyaxis right
    if (~isnan(widths))
        plot(reTriangulationIterations(2:end), widths(:,1), 'rs-', 'MarkerFaceColor', [1 0.5 0.5], 'LineWidth', 1.0, 'MarkerSize', 10); hold on
        plot(reTriangulationIterations(2:end), widths(:,2), 'rs-', 'MarkerFaceColor', [1 0.5 0.5], 'LineWidth', 1.0, 'MarkerSize', 10);
        plot(reTriangulationIterations(2:end), widths(:,3), 'rs-', 'MarkerFaceColor', [1 0.5 0.5], 'LineWidth', 1.0, 'MarkerSize', 10);
    end
    set(gca, 'YLim', [-1.5 0.1]);
     
    subplot(2,3,6);
    plotMeshQuality(hFig,histogramData, bin1Percent, []);
    drawnow
end

function q = computeQuality(coneLocs, triangles)
    
    trianglesNum = size(triangles,1);
    X = coneLocs(:,1);
    Y = coneLocs(:,2);
    
    q = zeros(1,trianglesNum);
    for triangleIndex = 1:trianglesNum
        for node = 1:3
            x(node) = X(triangles(triangleIndex,node));
            y(node) = Y(triangles(triangleIndex,node));
        end 
        aLength = sqrt((x(1)-x(2))^2 + (y(1)-y(2))^2);
        bLength = sqrt((x(1)-x(3))^2 + (y(1)-y(3))^2);
        cLength = sqrt((x(2)-x(3))^2 + (y(2)-y(3))^2);
        q(triangleIndex) = (bLength+cLength-aLength)*(cLength+aLength-bLength)*(aLength+bLength-cLength)/(aLength*bLength*cLength);
    end
end


function visualizeLatticeState(conePositions, triangleConeIndices)
    x = conePositions(:,1);
    y = conePositions(:,2);
    
    xx = []; yy = [];
    for triangleIndex = 1:size(triangleConeIndices, 1)
        coneIndices = triangleConeIndices(triangleIndex, :);
        xCoords = x(coneIndices);
        yCoords = y(coneIndices);
        for k = 1:numel(coneIndices)
            xx = cat(2, xx, xCoords);
            yy = cat(2, yy, yCoords);
        end
    end
    
    patch(xx, yy, [0 0 1], 'EdgeColor', [0.4 0.4 0.4], ...
        'EdgeAlpha', 0.5, 'FaceAlpha', 0.4, ...
        'FaceColor', [0.99 0.99 0.99], 'LineWidth', 1.0, ...
        'LineStyle', '-', 'Parent', gca); 
    hold on;
end


function inputVal = GetWithDefault(prompt,defaultVal)
    if (ischar(defaultVal))
        inputVal = input(sprintf([prompt ' [%s]: '],defaultVal),'s');
    else
        inputVal = input(sprintf([prompt ' [%g]: '],defaultVal));
    end
    if (isempty(inputVal))
        inputVal = defaultVal;
    end

end
