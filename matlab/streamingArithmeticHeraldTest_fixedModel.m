
clear all
close all
rng(4)
load('fixedModel012.mat');
%opens fixedModel
encoder = streamingArithmeticEncoder32_herald(fixedModel,5);
decoder = streamingArithmeticDecoder32_herald(fixedModel,5);
cw = [];
nSymbols = 50000;
txSymbols = sum((rand([2,nSymbols])>.3));
for idx = 1:nSymbols
    if(idx == nSymbols)
        cw = [cw,encoder.encodeSymbol(txSymbols(idx),true)];
    else
        cw = [cw,encoder.encodeSymbol(txSymbols(idx),false)];
    end
end
cwc = cw;
rx = [];
while(~isempty(cw))
   
    bits2add = randi(11)-1;
    if(bits2add > length(cw))
        bits2add = length(cw);
    end
    decoder.addBits(cw(1:bits2add));

    symbol = decoder.decodeSymbol();    
    
    
    
    
    
    
    
    if(symbol == -1)
        fprintf('\nwaiting\n');
    end
    
    
    
    number = 0;%will get one when we break out of loop
    while(symbol~=-1)
        rx = [rx,symbol];
        symbol = decoder.decodeSymbol();
        number = number+1;
    end
    
    fprintf('\n decoded %d symbols \n',number);
    
    cw = cw((bits2add+1):end); 
    
end

errorRate = sum(rx~=txSymbols(1:numel(rx)))/numel(rx)
