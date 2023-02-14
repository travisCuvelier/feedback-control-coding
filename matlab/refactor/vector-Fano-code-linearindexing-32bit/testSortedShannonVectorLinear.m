numTrials = 100;
mx = 5;
param = .3;
sourceSymbols(1,:) = min(geornd(param,[1,numTrials]),2);
sourceSymbols(2,:) =  min(geornd(param,[1,numTrials]),2);
biggestSymbolPerDimension = [2,2];
counts = [0,1,0,1,0,5,4,1,0];
encModel = sortedAdaptiveCountsVariableCutoffs32(counts,biggestSymbolPerDimension);
decModel = sortedAdaptiveCountsVariableCutoffs32(counts,biggestSymbolPerDimension);
enc = shannonEncoder32(encModel);
dec = shannonDecoder32(decModel);
decodedSymbols = [];
meanCodewordLength = 0; 

for idx = 1:numTrials
    codeword = enc.encodeSymbol(sourceSymbols(:,idx));
    meanCodewordLength = ((idx-1)/idx)*meanCodewordLength+length(codeword)/idx;
    encModel.updateModel(sourceSymbols(idx));
    decodedSymbols(:,idx) = dec.decodeCodeword(codeword);
    decModel.updateModel(decodedSymbols(idx)); 
end

sum(sourceSymbols(1:numTrials)~=decodedSymbols(1:numTrials))

s = 0;
for outcome = 0:mx
    p(outcome+1) = geopdf(outcome,param);
    s = s+geopdf(outcome,param);
end
p = p/s;
sourceEntropy = -log2(p)*p.'
meanCodewordLength
%acutally entropy is twice this as were doing two independent streams
%jointly encoded....
