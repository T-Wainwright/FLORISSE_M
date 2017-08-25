classdef floris<handle
    properties
        inputData
        outputData
        outputFlowField
        outputDataAEP
    end
    methods
        %% Constructor function initializes default inputData

        function self = floris(siteType,turbType,atmoType,...
                modelType,wakeType,wakeSum,deflType)
            
            addpath('functions'); % Model functions
            addpath('NREL5MW');   % Airfoil data
            
            % Default setup
            if ~exist('siteType','var');    siteType  = '9turb';   end
            if ~exist('turbType','var');    turbType  = 'NREL5MW'; end
            % Choose between 'uniform' 'boundary'
            if ~exist('atmoType','var');    atmoType  = 'uniform'; end
            % Choose between 'pitch' 'greedy' 'axialInduction'
            if ~exist('modelType','var');   modelType = 'pitch'; end
            % Choose between 'Zones' 'Gauss' 'Larsen' 'PorteAgel'
            if ~exist('wakeType','var');    wakeType  = 'Zones'; end
            % Choose between 'Katic' 'Voutsinas'
            if ~exist('wakeSum','var');     wakeSum   = 'Katic'; end
            % Choose between 'Jimenez' 'PorteAgel'
            if ~exist('deflType','var');    deflType  = 'PorteAgel'; end
            
            % Call function
            self.inputData = floris_loadSettings(siteType,turbType,...
                atmoType,modelType,wakeType,deflType);
            
            self.inputData.wakeSum  = wakeSum;
        end
        
        
        
        %% FLORIS single execution
        function [self,outputData] = run(self)
            % Run FLORIS simulation and reset visualization
            [self.outputData] = floris_core(self.inputData);
            self.outputFlowField = [];
            
            % Results saved internally, but also returns externally if desired.
            if nargout > 0; outputData = self.outputData; end
        end
        
      
        function [self] = optimize(self,optimizeYaw,optimizeAxInd)
            inputData = self.inputData;
            disp(['Performing optimization: optimizeYaw = ' num2str(optimizeYaw) ', optimizeAxInd: ' num2str(optimizeAxInd) '.']);
            
            % Define initial guess and bounds
            x0 = []; lb = []; ub = [];
            if optimizeYaw  
                x0 = [x0, inputData.yawAngles]; 
                lb = [lb, deg2rad(-25)*ones(inputData.nTurbs,1)];
                ub = [ub, deg2rad(+25)*ones(inputData.nTurbs,1)];
            end
            if optimizeAxInd
                if inputData.axialControlMethod == 0
                    x0 = [x0, inputData.pitchAngles];  
                    lb = [lb, deg2rad(0.0)*ones(inputData.nTurbs,1)];
                    ub = [ub, deg2rad(5.0)*ones(inputData.nTurbs,1)];
                elseif inputData.axialControlMethod == 1
                    disp(['Cannot optimize axialInd for axialControlMethod == 1.']);
                    if optimizeYaw == false
                        disp('Exiting optimization call.');
                        return; 
                    else
                        disp('Optimizing yaw only.');
                        optimizeAxInd = false;
                    end
                elseif inputData.axialControlMethod == 2
                    x0 = [x0, inputData.axialInd];     
                    lb = [lb, 0.0*ones(inputData.nTurbs,1)];
                    ub = [ub, 1/3*ones(inputData.nTurbs,1)];
                end
            end
            
            % Cost function
            function J = costFunction(x,inputData,optimizeYaw,optimizeAxInd)
                % Overwrite settings for yaw and/or axial induction
                if optimizeYaw;   inputData.yawAngles = x(1:inputData.nTurbs); end
                if optimizeAxInd
                    if inputData.axialControlMethod == 0
                        inputData.pitchAngles = x(end-inputData.nTurbs+1:end);
                    elseif inputData.axialControlMethod == 2
                        inputData.axialInd    = x(end-inputData.nTurbs+1:end); 
                    end
                end

                [outputData] = floris_core(inputData,0);
                J            = -sum(outputData.power);
            end
            
            cost = @(x)costFunction(x,self.inputData,optimizeYaw,optimizeAxInd);
              
            % Optimizer settings and optimization execution
            %options = optimset('Display','final','MaxFunEvals',1000 ); % Display nothing
            %options = optimset('Algorithm','sqp','Display','final','MaxFunEvals',1000,'PlotFcns',{@optimplotx, @optimplotfval} ); % Display convergence
            options = optimset('Display','final','MaxFunEvals',1e4,'PlotFcns',{@optimplotx, @optimplotfval} ); % Display convergence
            xopt    = fmincon(cost,x0,[],[],[],[],lb,ub,[],options);
            
            % Simulated annealing
            %options = optimset('Display','iter','MaxFunEvals',1000,'PlotFcns',{@optimplotx, @optimplotfval} ); % Display convergence
            %xopt    = simulannealbnd(cost,self.inputData.axialInd,lb,ub,options);
            
            % Display improvements
            P_bl  = -costFunction(x0,  inputData,optimizeYaw,optimizeAxInd); % Calculate baseline power
            P_opt = -costFunction(xopt,inputData,optimizeYaw,optimizeAxInd); % Calculate optimal power
            disp(['Initial power: ' num2str(P_bl/10^6) ' MW']);
            disp(['Optimized power: ' num2str(P_opt/10^6) ' MW']);
            disp(['Relative increase: ' num2str((P_opt/P_bl-1)*100) '%.']);
            
            % Overwrite current settings with optimized oness
            if P_opt > P_bl
                if optimizeYaw; self.inputData.yawAngles = xopt(1:inputData.nTurbs); end
                if optimizeAxInd
                    if inputData.axialControlMethod == 0
                        self.inputData.pitchAngles = xopt(end-inputData.nTurbs+1:end); 
                        self.inputData.axialInd    = NaN*ones(1,inputData.nTurbs);
                        % The implicit values for axialInd calculated from
                        % blade pitch angles can be found in outputData,
                        % under the 'turbine.axialInd' substructure.
                    elseif inputData.axialControlMethod == 2
                        self.inputData.pitchAngles = NaN*ones(1,inputData.nTurbs);
                        self.inputData.axialInd    = xopt(end-inputData.nTurbs+1:end); 
                    end
                end
            else
                disp('Optimization was unsuccessful. Sticking to old control settings.');
            end
            
            % Update outputData for optimized settings
            self.run(); 
        end

        function [self] = optimizeYaw(self)
            self.optimize(true,false);
        end
        
        function [self] = optimizeAxInd(self)
            self.optimize(false,true);
        end


        %% Visualize single FLORIS simulation results
        function [] = visualize(self,plotLayout,plot2D,plot3D)

            % Check if there is output data available for plotting
            if ~isstruct(self.outputData)
                disp([' outputData is not (yet) available/not formatted properly.' ...
                    ' Please run a (single) simulation, then call this function.']);
                return;
            end

            % Default visualization settings, if not specified
            if ~exist('plotLayout','var');  plotLayout = true;  end
            if ~exist('plot2D','var');      plot2D     = true;  end
            if ~exist('plot3D','var');      plot3D     = false; end

            % Set visualization settings
            self.outputFlowField.plotLayout      = plotLayout;
            self.outputFlowField.plot2DFlowfield = plot2D;
            self.outputFlowField.plot3DFlowfield = plot3D;

            self.outputFlowField = floris_visualization(self.inputData,self.outputData,self.outputFlowField);
        end


        %% Run FLORIS AEP calculations (multiple wind speeds and directions)
        function [self,outputDataAEP] = AEP(self,windRose)
            % WindRose is an N x 2 matrix with uIf in 1st column and
            % vIf in 2nd. The simulation will simulate FLORIS for each row.

            % Simulate over each uIf-vIf set (matrix row)
            for i = 1:size(windRose,1)
                self.inputData.uInfIf   = windRose(i,1);
                self.inputData.vInfIf   = windRose(i,2);
                [self.outputDataAEP{i}] = self.run();
            end

            % Results saved internally, but also returns externally if desired.
            if nargout > 0; outputDataAEP = self.outputDataAEP; end
        end
    end
end