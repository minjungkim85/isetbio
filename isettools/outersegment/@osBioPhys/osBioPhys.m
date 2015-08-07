classdef osBioPhys < outerSegment 
% @osBioPhys: Subclass of @OuterSegment that implements a biophysical model
% of the phototransduction cascade to convert cone isomerizations (R*) to 
% current (pA). The model was built by Fred Rieke, and details can be found
% at:
%
% http://isetbio.github.io/isetbio/cones/adaptation%20model%20-%20rieke.pdf
% and 
% https://github.com/isetbio/isetbio/wiki/Cone-Adaptation
%
% % Example code:
% nSamples = 2000;        % 2000 samples
% timeStep = 1e-4;        % time step
% flashIntens = 50000;    % flash intensity in R*/cone/sec (maintained for 1 bin only)
% sensor = sensorCreate('human');
% sensor = sensorSet(sensor, 'size', [1 1]); % only 1 cone
% sensor = sensorSet(sensor, 'time interval', timeStep); 
% stimulus = zeros(nSamples, 1);
% stimulus(1) = flashIntens;
% stimulus = reshape(stimulus, [1 1 nSamples]);
% sensor = sensorSet(sensor, 'photon rate', stimulus);
% noiseFlag = 0;
% adaptedOS = osBioPhys('noiseFlag', noiseFlag);
% sensor = sensorSet(sensor,'adaptation offset',params.bgVolts);
% adaptedOS = osBioPhysCompute(adaptedOS, sensor);
% osAdaptedCur = osBioPhysGet(adaptedOS,'ConeCurrentSignal');
% osAdaptedCur = osAdaptedCur - osAdaptedCur(:, :, nSamples);
% osBioPhysPlot(adaptedOS, sensor);


    % Public, read-only properties.
    properties (SetAccess = private, GetAccess = public)        
    end
    
    % Private properties. Only methods of the parent class can set these
    properties(Access = private)
    end
    
    % Public methods
    methods
        
        % Constructor
        function obj = osBioPhys(varargin)
            % Initialize the parent class
            obj = obj@outerSegment();
            
            % Initialize ourselves
            obj.initialize();
            
            % parse the varargin
            for k = 1:2:numel(varargin)
                obj.(varargin{k}) = varargin{k+1};
            end
        end
        
        % set function, see osBioPhysSet for details
        function obj = set(obj, param, val, varargin)
            osBioPhysSet(obj, param, val, varargin);
        end
        
        % get function, see osBioPhysGet for details
        function val = get(obj, param, varargin)
           val = osBioPhysGet(obj, param, varargin);
        end
      
    end
    
    % Methods that must only be implemented (Abstract in parent class).
    methods (Access=public)        
        function obj = compute(obj, sensor, varargin)
            % see osBioPhysCompute for details
            obj = osBioPhysCompute(obj, sensor, varargin);
        end
        function plot(obj, sensor)
            % see osBioPhysPlot for details
            osBioPhysPlot(obj, sensor);
        end
    end
    
    % Methods that are totally private (subclasses cannot call these)
    methods (Access = private)
        initialize(obj);
    end
    
end
