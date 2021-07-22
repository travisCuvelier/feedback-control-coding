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
            
        end
        
        function update(obj,measReal)
            
            % meaurement update
            innov = measReal - obj.C*obj.xpred;
            dummy = obj.Ppred*obj.C'; %this memoization might
                                      %be numerically bad        
            S = obj.C*dummy+obj.V;
            Kkf = dummy/S;
            obj.xpost = obj.xpred+Kkf*innov;
            obj.Ppost = (obj.I-Kkf*obj.C)*obj.Ppred;
                  
            % predict update
            obj.xpred = obj.AplusBK*obj.xpost;
            obj.Ppred = obj.A*(obj.Ppost)*obj.A'+obj.W;
            
        end
        
    end
end

