numTrials = 100;
mx = 5;
param = .3;
precision = 33;
sourceSymbols = min(geornd(param,[1,numTrials]),mx);
counts = [9,1,2,1,1,1];
encModel = sortedFixedCountsArb(counts,precision);
decModel = sortedFixedCountsArb(counts,precision);
enc = shannonEncoderArb(encModel,precision);
dec = shannonDecoderArb(decModel,precision);
decodedSymbols = zeros([1,numTrials]);
meanCodewordLength = 0; 

for idx = 1:numTrials
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

%next steps:
%look at profiler. Make an increment and decrement function. 


%the decoder is broken, I think the encoder is working correctly. If you
%run the script it's in the hypothesis part of the code. Will revise.
