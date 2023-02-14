clear all
close all

addpath('../../elias_omega')


%inverted pendulum model from https://ctms.engin.umich.edu/CTMS/index.php?example=InvertedPendulum&section=ControlDigital

%plant model

M = 0.5;
m = 0.2;
b = 0.1;
I = 0.006;
g = 9.8;
l = 0.3;

p = I*(M+m)+M*m*l^2; 

Act = [0      1              0           0;
     0 -(I+m*l^2)*b/p  (m^2*g*l^2)/p   0;
     0      0              0           1;
     0 -(m*l*b)/p       m*g*l*(M+m)/p  0];
Bct = [     0;
     (I+m*l^2)/p;
          0;
        m*l/p];

Tsample = 1/100;

A = expm(Act*Tsample);
plantDim = size(A,1);
B = sqrtm(integral(@(x) expm(Act*x)*Bct*Bct'*expm(Act'*x),0,Tsample,'ArrayValued',true));
W= .3*eye(4);%just made this up 
Q = eye(4);
R = eye(4);

[X,L,G] = idare(A,B,Q,R,zeros(plantDim),eye(plantDim)); 

minLQG = trace(X*W); %minimum achievable LQG cost... 356.166ish 

%sedumi can't really solve the RDF near the minimum LQG cost
policyStruct = rateDistortion(A,B,W,Q,R, 356.167,'mosek'); %about 13.5 bits
%policyStruct.C is the optimal measurement matrix assuming that the uniform
%quantization sensitivity is unity. 
%As such, policyStruct.V = eye(dimension)*sqrt(1/12);.
%policyStruct.K is the LQG certainty equivalent gain
%policyStruct.

numIterations = 5000000;

%preallocation for trajectories. Probably don't need to save these for this
%current experiement
x = zeros(plantDim,numIterations);
y = zeros(plantDim,numIterations);

sigma_init = sqrt(5); %assume that x is initialized as a zero mean
%gaussian with a variance of 500. 
x(:,1) = sigma_init*randn(plantDim,1);

xpred_init = zeros(plantDim,1); %initial plant estimate
Ppred_init = sigma_init^2*eye(plantDim);%"initial" post measurement KF 
%error covaraince 
encoderKF = simpleKalmanFilter(A,B,policyStruct.C,W,policyStruct.V,xpred_init,Ppred_init);
decoderKF = simpleKalmanFilter(A,B,policyStruct.C,W,policyStruct.V,xpred_init,Ppred_init);

cutoffs = [1001,101,21,21]; %if cutoff= [21,21,21,21] the quantizer will 
%have bins from -10 to 10 in intevals of 1 unit. Anything outside that must
%be sent another way (elias)
%rate distortion estimate is 13.5 bits or about 3.3 
%bits per dimension. 2^3.3 = 10ish. We doubled it.
tic
encoderModels = conditionalCountManager32(cutoffs);
decoderModels = conditionalCountManager32(cutoffs);

fprintf('Time to build model: %f \n',toc)
arithmeticEncoder = vectorArithmeticEncoder32(encoderModels);
arithmeticDecoder = vectorArithmeticDecoder32(decoderModels);

delta = eye(4);%sqrtm(12*policyStruct.V); to save time I hard coded delta
dither = rand(plantDim,numIterations)-.5;

herald = 0; 
totalOverflows = 0;
cwl =zeros(numIterations,1);
eliasLen = 0;

tic
for iteration = 1:numIterations

    measurement = policyStruct.C*(x(:,iteration)-encoderKF.xpred);
    symbols = quantizeAndThread(measurement+dither(:,iteration)).'; %asssumes delta = eye(4)
    overflows = symbols(symbols>cutoffs);
    nOverThisIt = length(overflows);
    symbols(symbols>cutoffs) = herald; %escape symbols
    totalOverflows = totalOverflows+nOverThisIt;
    bits = arithmeticEncoder.encodeTupleAndUpdateModel(symbols);
    nbitsWithoutOverflows = length(bits); %the 
    for overIdx = 1:nOverThisIt
        bits = [bits, omegaEncode(overflows(overIdx))];
    end
    cwl(iteration) = numel(bits);
    rxSymbols = arithmeticDecoder.decodePacketAndUpdate(bits);
    %this will be a tuple of symbols the same saize as cutoffs.
    %the decoder could maintain its own encoder and compute
    %bits = arithmeticEncoder_DecodersIndependentCopy(rxSymbols)
    %to compute nbitsWithoutOverflows (also, that's a prefix free set).
    bits = bits((nbitsWithoutOverflows+1):end);

    for rxidx = 1:numel(rxSymbols)
        if(rxSymbols(rxidx) == herald)
            rxSymbols(rxidx) = omegaDecode(bits);
            bits = bits(length(omegaEncode(rxSymbols(rxidx)))+1:end);
        end
    end

%works to this point, just need to compute estimate, apply conotrol, etc.


  measurement = unthreadAndReconstruct(rxSymbols).'+policyStruct.C*decoderKF.xpred-dither(:,iteration);
 
  encoderKF.measurementUpdate(measurement); %measurement can also be
                                            %computed at the decoder
                                            %as all details known there.
  decoderKF.measurementUpdate(measurement); %encoder KF and decoder kf are 
                                            %synchornized. storing both is
                                            %a waste of time
  controlInput = policyStruct.K*decoderKF.xpost;
  encoderKF.predictUpdate(controlInput);
  decoderKF.predictUpdate(controlInput);

  ccost(iteration) = (controlInput)'*R*controlInput;
  x(:,iteration+1) = A*x(:,iteration)+B*controlInput+sqrtm(W)*randn(plantDim,1);
  scost(iteration) = x(:,iteration+1)'*Q*x(:,iteration+1);
end

rate = mean(cwl)
ctrlCost = mean(scost+ccost)
fprintf('Time to run experiment: %f \n',toc)

%save('model_structure_variables','A','B','W','Q','R','policyStruct','cutoffs','encoderModels','decoderModels')
