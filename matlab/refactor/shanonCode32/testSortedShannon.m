numTrials = 1e5;
mx = 5;
param = .3;
sourceSymbols = min(geornd(param,[1,numTrials]),mx);
counts = [0,1,0,1,1,1];
encModel = sortedFixedCounts32(counts);
decModel = sortedFixedCounts32(counts);
enc = shannonEncoder32(encModel);
dec = shannonDecoder32(decModel);
decodedSymbols = zeros([1,numTrials]);
meanCodewordLength = 0; 

for idx = 1:1e5
    codeword = enc.encodeSymbol(sourceSymbols(idx));
    meanCodewordLength = ((idx-1)/idx)*meanCodewordLength+length(codeword)/idx;
    encModel.updateModel(sourceSymbols(idx));
    decodedSymbols(idx) = dec.decodeCodeword(codeword);
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
