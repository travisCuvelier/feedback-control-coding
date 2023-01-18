classdef kalmanFilter < handle

    properties
        A %system matrix
        B %feedback matrix
        W %process noise
        
        C %measurement matrix
        V %measurement noise
        
        K %control gain
        
        xpartialpred %a priori estimator/prediction (t+1|t)
        Ppred% a priori estimator/prediction covariance  (t+1|t)
        
        xpost %posterior estimator/prediction (t|t)
        Ppost %posterior estimator/prediction covariance  (t|t)
        
        nskips %number of skipped measurements
        
        inputHistory
        missedMeasurements 
        
        xbest
        Pbest
        t
        
        verbose
        
    end
    
    properties(Access = private)
        AplusBK
        I
    end
    
    methods
        function obj = kalmanFilter(A,B,C,W,V,K,xpost_init,Ppost_init,verbose)
            
            obj.A = A; %must be square
            obj.B = B;
            obj.C = C;
            obj.W = W;
            obj.V = V;
            obj.K = K;
            obj.verbose = verbose;
            
            obj.xpost = xpost_init;
            obj.Ppost = Ppost_init;
            obj.I = eye(size(A,1));
            obj.xpartialpred = obj.A*obj.xpost;
            
      
            
            obj.xbest = obj.xpost;
            obj.Pbest = obj.Ppost;
            obj.t = 0;

            
            obj.Ppred = obj.A*(obj.Ppost)*obj.A'+obj.W;
            
            obj.inputHistory = {};
            obj.missedMeasurements = 0; 
            
            
        end
        
        %can only call once per time step
        %not efficient. think about this. 
        %given control input at time t-1, and some measurements from times
        %1....,t, computes best estimate of x_t|(measurements recieved until time t)
        
        function zDelayTrigger = update(obj,measReal,controlInput)
            %warning('can only call once per time step');
            obj.t = obj.t+1;
            zDelayTrigger = false;
            
            if(isempty(measReal))
                
                obj.missedMeasurements = obj.missedMeasurements+1;
                obj.inputHistory{obj.missedMeasurements} = controlInput;
                obj.xbest = obj.A*obj.xbest+obj.B*controlInput;       
                obj.Pbest = obj.A*obj.Pbest*obj.A'+obj.W;
                
            elseif(obj.missedMeasurements == 0)
                
                if(obj.verbose)
                    fprintf('\nno delay\n');
                    zDelayTrigger = true;
                end
                
                if(numel(measReal)>1)
                    error('trying to integrate too many measurements')
                end
                
                xpred = obj.xpartialpred+obj.B*controlInput;
                % meaurement update
                innov = measReal{1} - obj.C*xpred;
                dummy = obj.Ppred*obj.C'; %this memoization might
                                      %be numerically bad        
                S = obj.C*dummy+obj.V;
                Kkf = dummy/S;
                obj.xpost = xpred+Kkf*innov;
                obj.Ppost = (obj.I-Kkf*obj.C)*obj.Ppred;
                obj.xpartialpred = obj.A*obj.xpost;
                obj.Ppred = obj.A*(obj.Ppost)*obj.A'+obj.W;
                obj.xbest = obj.xpost; 
                obj.Pbest = obj.Ppost;
                
            else
                
                if(numel(measReal)>(1+obj.missedMeasurements))
                    error('trying to integrate too many measurements')
                end
                                
                for idx = 1:min(numel(measReal),obj.missedMeasurements)
                    
                    xpred = obj.xpartialpred+obj.B*obj.inputHistory{idx};
                    innov = measReal{idx} - obj.C*xpred;
                    dummy = obj.Ppred*obj.C';
                    S = obj.C*dummy+obj.V;
                    Kkf = dummy/S;
                    obj.xpost = xpred+Kkf*innov;
                    obj.Ppost = (obj.I-Kkf*obj.C)*obj.Ppred;
                    obj.xpartialpred = obj.A*obj.xpost;
                    obj.Ppred = obj.A*(obj.Ppost)*obj.A'+obj.W;
                end
                
                if(min(numel(measReal),obj.missedMeasurements)==obj.missedMeasurements)
                    obj.inputHistory= {};
                else
                    obj.inputHistory = obj.inputHistory((numel(measReal)+1):end);
                end                
                
                obj.missedMeasurements = 1+obj.missedMeasurements-numel(measReal);
                
                if(obj.missedMeasurements==0)
                    xpred = obj.xpartialpred+obj.B*controlInput;
                    innov = measReal{end} - obj.C*xpred;
                    dummy = obj.Ppred*obj.C'; %this memoization might
                                      %be numerically bad        
                    S = obj.C*dummy+obj.V;
                    Kkf = dummy/S;
                    obj.xpost = xpred+Kkf*innov;
                    obj.Ppost = (obj.I-Kkf*obj.C)*obj.Ppred;
                    obj.xpartialpred = obj.A*obj.xpost;
                    obj.Ppred = obj.A*(obj.Ppost)*obj.A'+obj.W;
                    obj.xbest = obj.xpost; 
                    obj.Pbest = obj.Ppost;
                    obj.missedMeasurements = 0;
                    if(obj.verbose)
                        fprintf('\nno delay\n');
                        zDelayTrigger = true;
                        obj.t
                        obj.Pbest
                        obj.Pbest
                    end
                else
                    obj.inputHistory{obj.missedMeasurements} = controlInput;
                    obj.xbest = obj.xpost; 
                    obj.Pbest = obj.Ppost;
                    for idx = 1:obj.missedMeasurements
                        obj.xbest = obj.A*obj.xbest+obj.B*obj.inputHistory{idx};
                        obj.Pbest = obj.A*obj.Pbest*obj.A'+obj.W;
                    end
                end
                
            end
        end
        
        %computes x_(t+1)|(measurements recieved until time t) and control
        %input at time t
        %inefficient but idgaf
        function xpred = xPred(obj,controlInput)
            xpred = obj.A*obj.xbest+obj.B*controlInput;
        end
        
    end
end

