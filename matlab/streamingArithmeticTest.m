
clear all
close all

encoderModel = cutoffCounts32(2); 
encoder = streamingEncoder32(encoderModel);
decoderModel = cutoffCounts32(2); 
decoder = streamingDecoder32(decoderModel);
symbols = sum((rand([2,1e6])>.3));
decodedSymbols = zeros(size(symbols));
cwl = 0;
for symbolCount = 1:numel(symbols)
    codeword = encoder.getCodeword(symbols(symbolCount));
    cwl = cwl+length(codeword);
    encoderModel.updateModel(symbols(symbolCount));
    decodedSymbols(symbolCount) = decoder.decodeCodeword(codeword);
    decoderModel.updateModel(decodedSymbols(symbolCount));
end

mcwl = cwl/numel(symbols);

empiricalEntropy = 0;
for idx = 0:2
  p = sum(symbols==idx)/numel(symbols);
  empiricalEntropy= empiricalEntropy-p*log2(p);
end

sum(decodedSymbols==symbols)/numel(symbols)