
clear all
close all
rng(4)
load('fixedModel012.mat');
addpath('elias_omega')
%opens fixedModel
herald = 0;
encoder = streamingArithmeticEncoder32_herald(fixedModel,herald);
decoder = streamingArithmeticDecoder32_herald(fixedModel,herald);
cutoff = fixedModel.symbolLimit;
cw = [];
rx = [];
nMeasRX = 0;


txSymbols = randi(25,[1,9999]);
nSymbols = numel(txSymbols)

atEnd = false; 



for idx = 1:nSymbols
    
    if(idx ==nSymbols)
        atEnd = true;
    end
    
    if(txSymbols(idx) > cutoff)
        arithmeticBits = encoder.encodeSymbol(herald,atEnd);
        eliasCw = omegaEncode(txSymbols(idx));
        newBits = [arithmeticBits,eliasCw]; 
    else
        newBits = encoder.encodeSymbol(txSymbols(idx),atEnd);
    end
    
    decoder.addBits(newBits);
    
    
    while(1)
        symbol = decoder.decodeSymbol();
        if(symbol == -1)
            %fprintf('\nwaiting\n');
            break
        elseif(symbol == herald)
            
            realSymbol = omegaDecodeStreaming(decoder.runningHistory);
            rx = [rx,realSymbol];
            eliasSize = numel(omegaEncode(realSymbol));
            newDecoder = streamingArithmeticDecoder32_herald(fixedModel,herald);

            if(eliasSize < length(decoder.runningHistory))
               newBits = decoder.runningHistory((eliasSize+1):end);
               newDecoder.addBits(newBits);
            end
            
            decoder = newDecoder; 
        else
            rx = [rx,symbol];
        end
    end
    
    
end

while(length(rx)<nSymbols)

        symbol = decoder.decodeSymbol();
        if(symbol == -1)
            %fprintf('\nwaiting\n')
            decoder.addBits(rand>.5);
        elseif(symbol == herald)
            realSymbol = omegaDecodeStreaming(decoder.runningHistory);
            rx = [rx,realSymbol];

            eliasSize = numel(omegaEncode(realSymbol));
            newDecoder = streamingArithmeticDecoder32_herald(fixedModel,herald);

            if(eliasSize < length(decoder.runningHistory))
               newBits = decoder.runningHistory((eliasSize+1):end);
               newDecoder.addBits(newBits);
            end

            decoder = newDecoder;
        else
            rx = [rx,symbol];
        end

end


sum(abs(rx-txSymbols))



