% add the following directories to your MATLAB path
%see notes in YALMIP-master
% ->/YALMIP-master
% ->/YALMIP-master/extras
% ->/YALMIP-master/solvers
% ->/YALMIP-master/modules
% ->/YALMIP-master/modules/parametric
% ->/YALMIP-master/modules/moment
% ->/YALMIP-master/modules/global
% ->/YALMIP-master/modules/sos
% ->/YALMIP-master/operators
% addpath('../../YALMIP-master')
% addpath('../../YALMIP-master/extras')
% addpath('../../YALMIP-master/solvers')
% addpath('../../YALMIP-master/modules')
% addpath('../../YALMIP-master/modules/parametric')
% addpath('../../YALMIP-master/modules/moment')
% addpath('../../YALMIP-master/modules/global')
% addpath('../../YALMIP-master/modules/sos')
% addpath('../../YALMIP-master/operators')

% addpath('YALMIP-master')
% addpath('YALMIP-master/extras')
% addpath('YALMIP-master/solvers')
% addpath('YALMIP-master/modules')
% addpath('YALMIP-master/modules/parametric')
% addpath('YALMIP-master/modules/moment')
% addpath('YALMIP-master/modules/global')
% addpath('YALMIP-master/modules/sos')
% addpath('YALMIP-master/operators')

%varargin is a string that specifies solver, e.g. 'mosek' for MOSEK,
%'sdpt3' for SDPT3...

function policy = rateDistortion(A,B,W,Q,R,lqgCost,varargin) 
    
    if(isempty(varargin))
        solver = 'sdpt3';
    else
        solver = varargin{1};
    end
    
    n = size(A,1);
    cMat= controllabilityMatrix(A,B);
    [Tinv,e] = svd(cMat*cMat');
    ctrlDim = rank(e);

    if(ctrlDim <n)
        Atilde = Tinv\(A*Tinv);
        d = eigs(Atilde((ctrlDim+1):end,(ctrlDim+1):end),1);
        if(d >=1 )
            error('(A,B) is not stabilizable.') 
        end
    end
    
    cMat = controllabilityMatrix(A',Q');
    
    [Tinv,e] = svd(cMat*cMat');
    ctrlDim = rank(e);

    if(ctrlDim <n)
        Atilde = Tinv\(A*Tinv);
        d = eigs(Atilde((ctrlDim+1):end,(ctrlDim+1):end),1);
        if(d >=1 )
            error('(A,Q) is not detectable.') 
        end
    end
    
    [S,K,~] = idare(A,B,Q,R,zeros(n,size(B,2)),eye(n));
    K = -K; 
    Theta = K'*(B'*S*B+R)*K;
    
    P = sdpvar(n);
    V = sdpvar(n);
    F = [ P>=0, V >=0,trace(Theta*P)+trace(W*S)<= lqgCost,A*P*A'+W-P>=0, [P-V,P*A';A*P,A*P*A'+W]>=0  ];
    
    diagnostic=optimize(F,-logdet(V),sdpsettings('solver',solver,'verbose',0));
    if(diagnostic.problem)
        s = sprintf('%d\n',diagnostic.problem);
        warning(strcat('issues with solver, error code = ',s))
        diagnostic
    end
    
    policy.minimumCost = .5*(-log2(det(value(V))) +log2(det(W)));
    policy.P = value(P);
    policy.SNR = inv(policy.P)-inv(A*policy.P*A'+W);
    [U,E,~] = svd(policy.SNR);
    rk = 0;
    rplus = 1;
    while(rk < size(E,1) && E(rplus,rplus) ~=0)
        rk = rplus;
        rplus = rplus+1;
    end
    policy.rank = rk; 
    Uprime = U*sqrt(E)/sqrt(12);
    policy.C = (Uprime(:,1:rk))';
    policy.V = eye(rk)/12;
    policy.solverDiagnostics = diagnostic;
    
end