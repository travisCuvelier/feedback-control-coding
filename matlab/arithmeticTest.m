
clear all
close all

encoderModel = cutoffCounts32(2); 
encoder = arithmeticEncoder32(encoderModel,'data');

symbols = sum((rand([2,1.5e5])>.3));


for symbolCount = 1:numel(symbols)
    encoder.encodeSymbol(symbols(symbolCount));
    encoderModel.updateModel(symbols(symbolCount));
end
encoder.endEncoding();
decoderModel = cutoffCounts32(2); 
decoder = arithmeticDecoder32(decoderModel,'data');
decodedSymbols = [];
for symbolCount = 1:numel(symbols)
    decodedSymbols=[decodedSymbols,decoder.decodeSymbol()];
    decoderModel.updateModel(decodedSymbols(symbolCount));
end

sum(decodedSymbols==symbols)/numel(symbols)