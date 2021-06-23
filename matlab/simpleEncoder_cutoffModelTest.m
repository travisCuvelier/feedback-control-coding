

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

d1 = dir('data1');
bps1 =  d1.bytes*8/numel(symbols);
fprintf('without updating model, get %f bits/symbol.\n',bps1);
d2 = dir('data2');
bps2 =  d2.bytes*8/numel(symbols);
fprintf('with updating model, get %f bits/symbol.\n',bps2);
fprintf('Empirical entropy rate of source (assuming iid) is %f bits/symbol\n',empiricalEntropy)
