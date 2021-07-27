classdef kalmanFilter_dep < handle

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
        predictHistory
        delays 
        
    end
    
    properties(Access = private)
        AplusBK
        I
    end
    
    methods
        function obj = kalmanFilter(A,B,C,W,V,K,xpost_init,Ppost_init)
            
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
            obj.xpred = obj.AplusBK*obj.xpost;
            obj.Ppred = obj.A*(obj.Ppost)*obj.A'+obj.W;
            
            obj.inputHistory = {};
            obj.predictHistory = {};
            obj.delays = 0; 
            
            
        end
        
        function update(obj,measReal,varargin)
            
            % meaurement update
            innov = measReal - obj.C*obj.xpred;
            dummy = obj.Ppred*obj.C'; %this memoization might
                                      %be numerically bad        
            S = obj.C*dummy+obj.V;
            Kkf = dummy/S;
            obj.xpost = obj.xpred+Kkf*innov;
            obj.Ppost = (obj.I-Kkf*obj.C)*obj.Ppred;
                  
            % predict update
            if(isempty(varargin))
                obj.xpred = obj.AplusBK*obj.xpost;
            else
                obj.xpred = obj.A*obj.xpost+obj.B*varargin{1};
            end
            
            
            obj.Ppred = obj.A*(obj.Ppost)*obj.A'+obj.W;
            
        end
        
        function pred = nStepPrediction(obj,n)
            
            if(obj.delays == 0 && n>0)
                
                obj.delays = n;
                
                obj.predictHistory{1} = obj.xpred;
                obj.inputHistory{1} = obj.K*obj.predictHistory{1};

                for idx = 2:n
                    obj.predictHistory{idx} = obj.AplusBK*obj.predictHistory{idx-1};
                    obj.inputHistory{idx} = obj.K*obj.predictHistory{idx};
                end

                pred = obj.predictHistory{n};
                
            elseif(n>0 && obj.delays>=n)
                
                pred = obj.predictHistory{n};
                
            elseif(n>0)
                
                for idx = (obj.delays+1):n
                    obj.predictHistory{idx} = obj.AplusBK*obj.predictHistory{idx-1};
                    obj.inputHistory{idx} = obj.K*obj.predictHistory{idx};
                end
                
                obj.delays = n;
                pred = obj.predictHistory{n};  
                
            else
                pred = obj.xpost;
            end
            
            
        end
        
        %meas is a cell array containing measurements
        %precondition, numel(meas) is less than or equal to obj.delays
        function delayedMeasurements(obj,measurements)
            nmeas = numel(measurements);
            if(nmeas>obj.delays)
                error('you can''t integrate more measurements than there were delays')
            else
                for idx = 1:nmeas
                    obj.update(measurements{idx},obj.inputHistory{idx})
                end
                
                obj.delays = obj.delays-nmeas;
                obj.inputHistory = obj.inputHistory{nmeas+1:end};
                obj.predictHistory = obj.predictHistory{nmeas+1:end};
            end
        end
        
    end
end

