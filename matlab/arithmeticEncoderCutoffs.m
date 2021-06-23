

encoderModel = cutoffCounts32(2); 
encoder = arithmeticEncoder32(encoderModel,'data1');

symbols = [1,2,0,1,0,1,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,1,0,0,0,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,1,0,1,0,1,0,1,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,0,0,0,0,0,0,0,0,1,0,1,0,1,0,0,0,1,0];
symbols = repmat(symbols,1,2500);

for symbolCount = 1:numel(symbols)
    encoder.encodeSymbol(symbols(symbolCount));
    %encoderModel.updateModel(symbols(symbolCount));
end

encoder.endEncoding()


encoderModel = cutoffCounts32(2); 
encoder = arithmeticEncoder32(encoderModel,'data2');


for symbolCount = 1:numel(symbols)
    encoder.encodeSymbol(symbols(symbolCount));
    encoderModel.updateModel(symbols(symbolCount));
end

encoder.endEncoding()
empiricalEntropy = 0;
for idx = 0:2
  p = sum(symbols==idx)/numel(symbols);
  empiricalEntropy= empiricalEntropy-p*log2(p);
end

fprintf('check sizes of data 1 and data 2. Data one should be more than 1.5 bits, data 2 should be about 1 bit');