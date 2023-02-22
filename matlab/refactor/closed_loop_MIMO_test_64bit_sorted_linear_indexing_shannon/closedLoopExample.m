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
numIterations = 100000;
cutoffs = [1023,15,3,3]; %if cutoff= [21,21,21,21] the quantizer will 
%have bins from -10 to 10 in intevals of 1 unit. Anything outside that must
%be sent another way (elias)
%rate distortion estimate is 13.5 bits or about 3.3 
%bits per dimension. 2^3.3 = 10ish. We doubled it.
    
uniformPrior = uint64(ones(prod(cutoffs+1),1));
delta = eye(4);%sqrtm(12*policyStruct.V); to save time I hard coded delta
herald = 0;

trialIndex = 0;
for targetControlCost = linspace(1.001*356.167,1.01*356.167,8)
 %linspace(356.167*.99999983,1.001*356.167,15)
trialIndex = trialIndex+1;
    %sedumi can't really solve the RDF near the minimum LQG cost
    policyStruct = rateDistortion(A,B,W,Q,R, targetControlCost,'mosek'); %about 13.5 bits
    %policyStruct.C is the optimal measurement matrix assuming that the uniform
    %quantization sensitivity is unity. 
    %As such, policyStruct.V = eye(dimension)*sqrt(1/12);.
    %policyStruct.K is the LQG certainty equivalent gain
    %policyStruct.
    bound = policyStruct.minimumBits+1+plantDim*(log2(2*pi*exp(1)/12)+1);

    %preallocation and reset. Probably don't need to save these for this
    %current experiement
    x = zeros(plantDim,numIterations);
    
    
    sigma_init = sqrt(5); %assume that x is initialized as a zero mean
    %gaussian with a variance of 500. 
    x(:,1) = sigma_init*randn(plantDim,1);
    
    xpred_init = zeros(plantDim,1); %initial plant estimate
    Ppred_init = sigma_init^2*eye(plantDim);%"initial" post measurement KF 
    %error covaraince 
    encoderKF = simpleKalmanFilter(A,B,policyStruct.C,W,policyStruct.V,xpred_init,Ppred_init);
    decoderKF = simpleKalmanFilter(A,B,policyStruct.C,W,policyStruct.V,xpred_init,Ppred_init);
    
    encoderModel = sortedAdaptiveCountsVariableCutoffs64(uniformPrior,cutoffs);
    decoderModel = sortedAdaptiveCountsVariableCutoffs64(uniformPrior,cutoffs);
    
    shannonEncoder = shannonEncoder64(encoderModel);
    shannonDecoder = shannonDecoder64(decoderModel);
 

    dither = rand(plantDim,numIterations)-.5;
    
    totalOverflows = 0;
    cwl =zeros(1,numIterations);
    eliasLen = 0;
    cumoverflows = zeros(1,4);

    for iteration = 1:numIterations
    
        if(mod(iteration,1000)==0)
            fprintf('%3d %% iteration of %5.2f \n',iteration*100/numIterations,targetControlCost)
        end
    
        measurement = policyStruct.C*(x(:,iteration)-encoderKF.xpred);
        symbols = quantizeAndThread(measurement+dither(:,iteration)).'; %asssumes delta = eye(4)
        overflows = symbols(symbols>cutoffs);
    
        cumoverflows = cumoverflows+(symbols>cutoffs);
        nOverThisIt = length(overflows);
        symbols(symbols>cutoffs) = herald; %escape symbols
        totalOverflows = totalOverflows+nOverThisIt;
        
        bits = shannonEncoder.encodeSymbol(symbols);
        encoderModel.updateModel(symbols)
    
        nbitsWithoutOverflows = length(bits); %the 
        for overIdx = 1:nOverThisIt
            bits = [bits, omegaEncode(overflows(overIdx))];
        end
        cwl(iteration) = numel(bits);
    
        rxSymbols = shannonDecoder.decodeCodeword(bits);
        decoderModel.updateModel(rxSymbols)
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
    
    tcontrolcost = scost+ccost;
    for idx = 1:numIterations
        partialmeanlens(idx) = mean(cwl(1:idx));
        partialmeancontrols(idx) = mean(tcontrolcost(1:idx));
    end
    
    rate = mean(cwl);
    
    ctrlCost = mean(tcontrolcost)
    saverstring = sprintf('day_4_trial_index_%d_num_its_%d.mat',trialIndex,numIterations)
    save(saverstring)
    fprintf('clock time \n')
    clock
    fprintf('\n')


end
