%load('tanaka_SDP_sys');
%policyStruct = rateDistortion(A,B,W,Q,R,55); %setting cost fo 32 gives a bitrate of about 8.7 bits/symbol 

A = 2;
B = .1; 
W = 1;
Q = 1;
R = 1;
policyStruct = rateDistortion(2,.1,1,1,1,301.36); %about 7.48 bits

plantDim = size(A,1);
numIterations = 10000000;
x = zeros(plantDim,numIterations);
y = zeros(plantDim,numIterations);

sigma_init = sqrt(500);
x(:,1) = sigma_init*randn(plantDim,1);
xpost_init = zeros(plantDim,1);
Ppost_init = sigma_init^2*eye(plantDim);
kf = kalmanFilter(A,B,policyStruct.C,W,policyStruct.V,policyStruct.K,xpost_init,Ppost_init);

for iteration = 1:numIterations
  
  p(iteration) = trace(kf.Ppost);
  measurement = policyStruct.C*x(:,iteration)+sqrtm(policyStruct.V)*randn(plantDim,1);
  kf.update(measurement);
  ccost(iteration) = (policyStruct.K*kf.xpost)'*R*policyStruct.K*kf.xpost;
  x(:,iteration+1) = A*x(:,iteration)+B*policyStruct.K*kf.xpost+sqrtm(W)*randn(plantDim,1);
  scost(iteration) = x(:,iteration+1)'*Q*x(:,iteration+1);
end
    


