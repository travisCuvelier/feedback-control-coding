clear all
close all
%load('tanaka_SDP_sys');
%policyStruct = rateDistortion(A,B,W,Q,R,31.7); %setting cost fo 32 gives a bitrate of about 8.7 bits/symbol 

addpath('elias_omega')


A = 2;
B = .1; 
W = 1;
Q = 1;
R = 1;
policyStruct = rateDistortion(A,B,W,Q,R,900); %301.36 works for about 7.5 bits.

plantDim = size(A,1);

numIterations = 5000;
x = zeros(plantDim,numIterations);
y = zeros(plantDim,numIterations);

sigma_init = sqrt(500);
x(:,1) = sigma_init*randn(plantDim,1);
xpost_init = zeros(plantDim,1);
Ppost_init = sigma_init^2*eye(plantDim);

txKF = kalmanFilter(A,B,policyStruct.C,W,policyStruct.V,policyStruct.K,xpost_init,Ppost_init);
rxKF = kalmanFilter(A,B,policyStruct.C,W,policyStruct.V,policyStruct.K,xpost_init,Ppost_init);
cutoff = 101;
herald = 0;
encoderModel = cutoffCounts32(cutoff); 
encoder = streamingArithmeticEncoder32_herald(encoderModel,herald);
decoderModel = cutoffCounts32(cutoff); 
decoder = streamingArithmeticDecoder32_herald(decoderModel,herald);


delta = sqrtm(12*policyStruct.V);

dither = delta*(rand(plantDim,numIterations)-.5);
nOverflows = 0;
cwl = 0;
eliasLen = 0;

atEnd = false;

missedMeasurements = 0;

for iteration = 1:numIterations
    
  if(iteration==numIterations)
      atEnd = true;
  end
  
  measurement = policyStruct.C*(x(:,iteration)-kf.xpred);
  txSymbol = quantizeAndThread(measurement+dither(:,iteration),diag(delta));
  recieved = zeros(plantDim,1);
  
  codeword = [];
    
  %need to handle zeros specially not done yet, not enough time.
  if(txSymbol>cutoff)
      arithmeticBits = encoder.encodeSymbol(herald,atEnd);
      eliasCw = omegaEncode(txSymbol);
      codeword = [arithmeticBits,eliasCw]; 
      encoderModel.updateModel(herald,iteration);
      cwl = cwl+length(codeword);
      nOverflows = nOverflows+1;
      eliasLen = eliasLen+length(eliasCw);
  else
      codeword = encoder.getCodeword(txSymbol);
      encoderModel.updateModel(txSymbol,iteration);
      cwl = cwl+length(codeword);
  end
  
  decoder.addBits(codeword);
  
  
   
  
  
  
  
  
  
  
  
  rxSymbol = decoder.decodeCodeword(codeword);
  %decoder would compute heraldLength (independently of encoder)
  %here before updating model
  
  decoderModel.updateModel(rxSymbol);
  
  if(rxSymbol == herald)
      
      eliasCw = codeword(heraldLength+1:end); %decoder can compute heraldLength easily.
      recieved(idx) = omegaDecode(eliasCw);
      
  else
      recieved(idx) = rxSymbol;
  end
  
  
  
  
  measurement = unthreadAndReconstruct(recieved,diag(delta))+policyStruct.C*kf.xpred-dither(:,iteration);
 
  kf.update(measurement);
  ccost(iteration) = (policyStruct.K*kf.xpost)'*R*policyStruct.K*kf.xpost;
  x(:,iteration+1) = A*x(:,iteration)+B*policyStruct.K*kf.xpost+sqrtm(W)*randn(plantDim,1);
  scost(iteration) = x(:,iteration+1)'*Q*x(:,iteration+1);
end

rate = cwl/numIterations
ctrlCost = mean(scost+ccost)