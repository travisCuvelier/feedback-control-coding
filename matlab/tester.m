load('dynamicalSys');
A = dynamicalSys.A;
B =  dynamicalSys.B;
W = dynamicalSys.W;
Q = dynamicalSys.Q;
R = dynamicalSys.R;
lqgCost = 202700;
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
    F = [ P>=0, V>=0,trace(Theta*P)+trace(W*S)<= lqgCost,A*P*A'+W-P>=0, [P-V,P*A';A*P,A*P*A'+W]>=0  ];
    
   diagnostic = optimize(F,-logdet(V),sdpsettings('solver','sdpt3','verbose',0));
    
    if(diagnostic.problem)
        s = sprintf('%d\n',diagnostic.problem);
        warning(strcat('potentially fatal issues with solver, error code = ',s))
        diagnostic
    end
    
    policy.minimum = .5*(-log2(det(value(V))) +log2(det(W)));
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
    C = U';
    policy.C=C(1:rk,:);
    policy.V = inv(E(1:rk,1:rk));
