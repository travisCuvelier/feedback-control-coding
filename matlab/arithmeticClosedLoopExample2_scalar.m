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

numIterations = 100000;
x = zeros(plantDim,numIterations);
y = zeros(plantDim,numIterations);

sigma_init = sqrt(500);
xpost_init = zeros(plantDim,1);
Ppost_init = sigma_init^2*eye(plantDim);
inputDim = size(B,2);
rxKF = kalmanFilter(A,B,policyStruct.C,W,policyStruct.V,policyStruct.K,xpost_init,Ppost_init);
controlInput = policyStruct.K*rxKF.xbest;
x(:,1) = A*sigma_init*randn(plantDim,1)+B*controlInput;


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

nMeasurementsRecieved = 0;

predictMemory = [];
txRecord = [];
rxRecord = [];

for iteration = 1:numIterations
    
  if(iteration==numIterations)
      atEnd = true;
  end
  
  xpred = rxKF.xPred(controlInput); %E(x_{iteration|iteration-1 measurements}
  innovation = policyStruct.C*(x(:,iteration)-xpred);
  txSymbol = quantizeAndThread(innovation+dither(:,iteration),diag(delta));
  txRecord = [txRecord,txSymbol];
  predictMemory(:,size(predictMemory,2)+1) = xpred; %E(x_{iteration|iteration-1 measurements}
  
  
  %encode the codeword
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
      codeword = encoder.encodeSymbol(txSymbol,atEnd);
      encoderModel.updateModel(txSymbol,iteration);
      cwl = cwl+length(codeword);
  end
  
  %done encoding. now start decoding.
  
  %receive the codeword and add bits to the decoder
  decoder.addBits(codeword);
  newRX = [];  
  while(1)
      symbol = decoder.decodeSymbol();
      if(symbol == -1)
          %fprintf('\nwaiting\n');
          break
      elseif(symbol == herald)
          decoderModel.updateModel(herald,iteration);
          realSymbol = omegaDecodeStreaming(decoder.runningHistory);
          newRX = [newRX,realSymbol];
          eliasSize = numel(omegaEncode(realSymbol));
          newDecoder = streamingArithmeticDecoder32_herald(fixedModel,herald);
          if(eliasSize < length(decoder.runningHistory))
              newBits = decoder.runningHistory((eliasSize+1):end);
              newDecoder.addBits(newBits);
          end
          decoder = newDecoder;
      else
          newRX = [newRX,symbol];
          decoderModel.updateModel(symbol,iteration);
      end
  end
  
  rxRecord = [rxRecord,newRX];
  
  nNewMeas = length(newRX);
  %nMeasurementsRecieved = nMeasurementsRecieved+nNewMeas; 
  %totalDeficit = iteration-nMeasurementsRecieved;
  newMeasurements = {};
  for idx = 1:nNewMeas
      nMeasurementsRecieved = nMeasurementsRecieved+1;
      newMeasurements{idx} = unthreadAndReconstruct(newRX(idx),diag(delta))+policyStruct.C*predictMemory(:,idx)-dither(:,nMeasurementsRecieved);
  end
  
  delays(iteration) = nMeasurementsRecieved-iteration;
  
  predictMemory = predictMemory(:,(nNewMeas+1):end);
  rxKF.update(newMeasurements,controlInput);
  controlInput = policyStruct.K*rxKF.xbest;
  ccost(iteration) = (controlInput)'*R*controlInput;
  x(:,iteration+1) = A*x(:,iteration)+B*controlInput+sqrtm(W)*randn(plantDim,1);
  scost(iteration) = x(:,iteration+1)'*Q*x(:,iteration+1);
end

rate = cwl/numIterations
ctrlCost = mean(scost+ccost)