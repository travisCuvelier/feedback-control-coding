classdef kalmanFilter < handle

    properties
        A %system matrix
        B %feedback matrix
        W %process noise
        
        C %measurement matrix
        V %measurement noise
        
        K %control gain
        
        xpred %a priori estimator/prediction (t+1|t)
        Ppred% a priori estimator/prediction covariance  (t+1|t)
        
        xpost %posterior estimator/prediction (t|t)
        Ppost %posterior estimator/prediction covariance  (t|t)
        
        nskips %number of skipped measurements
        
        inputHistory
        missedMeasurements 
        
        xbest
        t
        
    end
    
    properties(Access = private)
        AplusBK
        I
    end
    
    methods
        function obj = kalmanFilter(A,B,C,W,V,K,xpost_init,Ppost_init,varargin)
            
            obj.A = A; %must be square
            obj.B = B;
            obj.C = C;
            obj.W = W;
            obj.V = V;
            obj.K = K;
            obj.AplusBK = obj.A+obj.B*obj.K;
            obj.xpost = xpost_init;
            obj.Ppost = Ppost_init;
            obj.I = eye(size(A,1));
            
            %first predict update
            if(isempty(varargin))
                obj.xpred = obj.AplusBK*obj.xpost;
            else
                obj.xpred = obj.A*obj.xpost+obj.B*varargin{1};
            end
            
            obj.xbest = obj.xpost;
            obj.t = 0;

            
            obj.Ppred = obj.A*(obj.Ppost)*obj.A'+obj.W;
            
            obj.inputHistory = {};
            obj.missedMeasurements = 0; 
            
            
        end
        
        %can only call once per time step
        %not efficient. think about this. 
        function update(obj,measReal,controlInput)
            warning('can only call once per time step');
            obj.t = obj.t+1;
            
            
            if(isempty(measReal))
                
                obj.missedMeasurements = obj.missedMeasurements+1;
                obj.inputHistory{obj.missedMeasurements} = controlInput;
                obj.xbest = obj.A*obj.xbest+obj.B*controlInput;       
                
            elseif(obj.missedMeasurements == 0)
                
                if(numel(measReal)>1)
                    error('trying to integrate too many measurements')
                end
                
                % meaurement update
                innov = measReal{1} - obj.C*obj.xpred;
                dummy = obj.Ppred*obj.C'; %this memoization might
                                      %be numerically bad        
                S = obj.C*dummy+obj.V;
                Kkf = dummy/S;
                obj.xpost = obj.xpred+Kkf*innov;
                obj.Ppost = (obj.I-Kkf*obj.C)*obj.Ppred;
                obj.xpred = obj.A*obj.xpost+obj.B*controlInput;
                obj.Ppred = obj.A*(obj.Ppost)*obj.A'+obj.W;
                obj.xbest = obj.xpost; 
                
            else
                
                if(numel(measReal)>(1+obj.missedMeasurements))
                    error('trying to integrate too many measurements')
                end
                                
                for idx = 1:min(numel(measReal),obj.missedMeasurements)
                    innov = measReal{idx} - obj.C*obj.xpred;
                    dummy = obj.Ppred*obj.C';
                    S = obj.C*dummy+obj.V;
                    Kkf = dummy/S;
                    obj.xpost = obj.xpred+Kkf*innov;
                    obj.Ppost = (obj.I-Kkf*obj.C)*obj.Ppred;
                    obj.xpred = obj.A*obj.xpost+obj.B*obj.inputHistory{idx};
                    obj.Ppred = obj.A*(obj.Ppost)*obj.A'+obj.W;
                end
                
                if(min(numel(measReal),obj.missedMeasurements)==obj.missedMeasurements)
                    obj.inputHistory= {};
                else
                    obj.inputHistory = obj.inputHistory{(numel(measReal)+1):end};
                end                
                
                obj.missedMeasurements = 1+obj.missedMeasurements-numel(measReal);
                
                if(obj.missedMeasurements==0)
                    innov = measReal{end} - obj.C*obj.xpred;
                    dummy = obj.Ppred*obj.C'; %this memoization might
                                      %be numerically bad        
                    S = obj.C*dummy+obj.V;
                    Kkf = dummy/S;
                    obj.xpost = obj.xpred+Kkf*innov;
                    obj.Ppost = (obj.I-Kkf*obj.C)*obj.Ppred;
                    obj.xpred = obj.A*obj.xpost+obj.B*controlInput;
                    obj.Ppred = obj.A*(obj.Ppost)*obj.A'+obj.W;
                    obj.xbest = obj.xpost; 
                    obj.missedMeasurements = 0;
                else
                    obj.inputHistory{obj.missedMeasurements} = controlInput;
                    obj.xbest = obj.xpost; 
                    for idx = 1:obj.missedMeasurements
                        obj.xbest = obj.A*obj.xbest+obj.B*obj.inputHistory{idx};
                    end
                end
                
            end
        end
        
    end
end

