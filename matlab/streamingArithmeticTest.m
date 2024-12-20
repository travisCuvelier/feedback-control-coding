
clear all
close all
rng(4)
encoderModel = cutoffCounts32(2); 
decoderModel = cutoffCounts32(2); 

encoder = streamingArithmeticEncoder32(encoderModel);
decoder = streamingArithmeticDecoder32(decoderModel);
cw = [];
nSymbols = 100000;
txSymbols = sum((rand([2,nSymbols])>.3));
for idx = 1:nSymbols
    if(idx == nSymbols)
        cw = [cw,encoder.encodeSymbol(txSymbols(idx),true)];
    else
        cw = [cw,encoder.encodeSymbol(txSymbols(idx),false)];
    end
    encoderModel.updateModel(txSymbols(idx)); 
end

rx = [];
while(~isempty(cw))
   
    bits2add = randi(11)-1;
    if(bits2add > length(cw))
        bits2add = length(cw);
    end
    decoder.addBits(cw(1:bits2add));
    
    number = 0;
    
    while(1)
        symbol = decoder.decodeSymbol();
        if(symbol == -1)
            fprintf('\nwaiting\n')
            break
        else
            number = number+1;
            rx = [rx,symbol];
            decoderModel.updateModel(symbol); 
        end
    end

    fprintf('\n decoded %d symbols \n',number);
    
    cw = cw((bits2add+1):end); 
    
end

errorRate = sum(rx(1:nSymbols)~=txSymbols)/nSymbols;
