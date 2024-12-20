clear all
close all
%load('tanaka_SDP_sys');
%policyStruct = rateDistortion(A,B,W,Q,R,31.7); %setting cost fo 32 gives a bitrate of about 8.7 bits/symbol 

%I think a bound on the suboptimality of the MMSE estimator 
%for a max delay of n is given by a^(2n)(Pmin-W/(1-a^2))+W/(1-a^2)
%this bound is interesting when a is stable. it reduces to
%max(W/(1-a^2),Pmin);
%notably, this is independent of n.


addpath('elias_omega')
msetx = [];
msetx2 = [];
mserx1 =[];
mserx2 =[];

A =1;
B = .1; 
W = 1;
Q = 1;
R = 1;
policyStruct = rateDistortion(A,B,W,Q,R,12); %A = 2, 301.36 works for about 7.5 bits. A = 1, cost = 12, A = .9, cost = 4.5

plantDim = size(A,1);

numIterations = 100000;
x = zeros(plantDim,numIterations);
y = zeros(plantDim,numIterations);

sigma_init = sqrt(500);
xpost_init = zeros(plantDim,1);
Ppost_init = sigma_init^2*eye(plantDim);
inputDim = size(B,2);
rxKF = kalmanFilter(A,B,policyStruct.C,W,policyStruct.V,policyStruct.K,xpost_init,Ppost_init,false);
txKF = kalmanFilter(A,B,policyStruct.C,W,policyStruct.V,policyStruct.K,xpost_init,Ppost_init,false);
controlInput = policyStruct.K*rxKF.xbest;
x(:,1) = A*sigma_init*randn(plantDim,1)+B*controlInput+sqrtm(W)*randn(plantDim,1);


cutoff = 277;
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
txMeasRec = [];
rxMeasRec = [];
for iteration = 1:numIterations
    
  if(iteration==numIterations)
      atEnd = true;
  end
  
  xpred = txKF.xPred(controlInput); %E(x_{iteration|iteration-1 measurements}
  innovation = policyStruct.C*(x(:,iteration)-xpred);
  txSymbol = quantizeAndThread(innovation+dither(:,iteration),diag(delta));
  txRecord = [txRecord,txSymbol];
  
  %when the decoder has recieved n measurements, it can compute E(x_(n+1|n)).
  %to save time, we save this sequence using the encoder kf. 
  predictMemory(:,size(predictMemory,2)+1) = xpred; %E(x_{iteration|iteration-1 measurements}
  
  %encoder knows what decoder will eventually recieve. 
  measurementToBeRecieved = unthreadAndReconstruct(txSymbol,diag(delta))+policyStruct.C*xpred-dither(:,iteration);
  %txMeasRec = [txMeasRec,measurementToBeRecieved];
  txKF.update({measurementToBeRecieved},controlInput);
  
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
          newDecoder = streamingArithmeticDecoder32_herald(decoderModel,herald);
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
      %rxMeasRec = [rxMeasRec,newMeasurements{idx}];
  end
  
  delays(iteration) = iteration-nMeasurementsRecieved;
  
  predictMemory = predictMemory(:,(nNewMeas+1):end);
  rxKF.update(newMeasurements,controlInput);
  msetx = [msetx, txKF.Ppost];
  msetx2 = [msetx2,(txKF.xpost-x(:,iteration))'*(txKF.xpost-x(:,iteration))];
  mserx1 = [mserx1, rxKF.Ppost];
  mserx2 = [mserx2, rxKF.Pbest];

  controlInput = policyStruct.K*rxKF.xbest;
  ccost(iteration) = (controlInput)'*R*controlInput;
  x(:,iteration+1) = A*x(:,iteration)+B*controlInput+sqrtm(W)*randn(plantDim,1);
  scost(iteration) = x(:,iteration+1)'*Q*x(:,iteration+1);
end

rate = cwl/numIterations
ctrlCost = mean(scost+ccost)