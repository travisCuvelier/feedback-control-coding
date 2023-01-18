addpath('../integer_arithmetic')
numTrials = 10000;
mx = 12;
param = .3;
precision = 16;
sourceSymbols = min(geornd(param,[1,numTrials]),mx);
counts = ones([1,13]);
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
    if(mod(idx,25)==0)
        idx
    end
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
