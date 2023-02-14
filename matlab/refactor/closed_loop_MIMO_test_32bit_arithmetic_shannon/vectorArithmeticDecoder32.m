classdef vectorArithmeticDecoder32 < handle
   
    properties(Constant)
        
        wordSize = 16;
        precision = 32;
        codewordMask = uint32(2^16-1)
        
    end
    
    properties (SetAccess = public, GetAccess = public)
        modelManager
        dimensions
        maxSymbolPerDimension
        nSymbolsPerDimension

        topValue
        firstQuarter
        half
        thirdQuarter
        cutoff %if symbol > cutoff send 0, then send an elias coded integer
        low
        high
        buff
        file
        value
        bitsInValue
        nDummies
    end
    
    
    methods
        %constructor
        function obj = vectorArithmeticDecoder32(modelManager)
            obj.topValue = bitshift(uint32(1),obj.wordSize)-1;%have to modify by hand
            obj.firstQuarter = bitshift(obj.topValue,-2)+1;
            obj.half = bitshift(obj.firstQuarter,1);
            obj.thirdQuarter = obj.half+obj.firstQuarter;
            obj.low = uint32(0);
            obj.high = obj.topValue; 
            warning('The encoder updates the model as it encodes, ensure that the model you pass in is "new" and initialized the same as with the encoder. DO NOT PASS IN THE ENCODER MODEL HANDLE');
            obj.value = uint32(0);
            obj.buff = [];
            obj.bitsInValue = 0; 

            obj.modelManager = modelManager; 
            obj.dimensions = obj.modelManager.dimensions; 
            obj.maxSymbolPerDimension = obj.modelManager.maxSymbolPerDimension;
            obj.nSymbolsPerDimension = obj.modelManager.nSymbolsPerDimension;


            %obj.value = uint32(fread(obj.file,1,'uint16'));
            %obj.buff =  uint16(fread(obj.file,1,'uint16'));%this outer cast
            %if(isempty(obj.buff))                          %is actually reqd                                                         %required.
             %  obj.buff =  uint16(0);  
            %end                                             
            %obj.bitsInBuffer = obj.wordSize; 
        end
        

        function tuple = decodePacketAndUpdate(obj,newBits)
                        %need this invariant: if bitsInValue < wordSize then buffer is
            %empty. 
            if(obj.bitsInValue < obj.wordSize && ~isempty(obj.buff))
                error('travis messed up');
            end
            
            %initially fill value
            %maybe need a different procedure for initializ
            while(~isempty(newBits)&& obj.bitsInValue < obj.wordSize)
                obj.value = bitand(bitshift(obj.value,1),obj.codewordMask)+uint32(newBits(1));%masking very necessary now.
                newBits = newBits(2:end);
                obj.bitsInValue = obj.bitsInValue+1;
            end

            while(obj.bitsInValue < obj.wordSize)
                obj.value = bitand(bitshift(obj.value,1),obj.codewordMask);
                obj.bitsInValue = obj.bitsInValue+1;
            end
            
            while(~isempty(newBits))
                obj.buff = [obj.buff,newBits(1)];
                newBits = newBits(2:end);
            end

            tuple = zeros(1,obj.dimensions);
            
            for didx = 1:obj.dimensions
                model = obj.modelManager.getModel(didx,tuple(1:didx-1));
                symbol = obj.decodeSymbol(model);
                model.updateModel(symbol);
                tuple(didx) = symbol;
            end

            %wipe the decoder state after each tuple. 
            obj.topValue = bitshift(uint32(1),obj.wordSize)-1;%have to modify by hand
            obj.firstQuarter = bitshift(obj.topValue,-2)+1;
            obj.half = bitshift(obj.firstQuarter,1);
            obj.thirdQuarter = obj.half+obj.firstQuarter;
            obj.low = uint32(0);
            obj.high = obj.topValue; 
            obj.value = uint32(0);
            obj.buff = [];
            obj.bitsInValue = 0; 
        end
            



        function symbol =  decodeSymbol(obj,model)%does not actually even output any bits
     
            %we can decode a symbol so long as there are at least wordSize
            %bits in value;
            %this has more delay than it should.
            if(obj.bitsInValue == obj.wordSize)
            
                range = (obj.high-obj.low)+1; %this is in 32 bits so it won't overflow; Initially should be 2^wordSize

                cum = idivide(((obj.value-obj.low+1)*model.cumCount(0)-1),range);%shouldn't overflow but likely culprit

                symbolIdx = 1;
                while(model.cumCount(symbolIdx)>cum)
                    symbolIdx = symbolIdx+1;
                end
                obj.high = obj.low + idivide((range*model.cumCount(symbolIdx-1)),model.cumCount(0))-1;
                obj.low =  obj.low + idivide((range*model.cumCount(symbolIdx)),model.cumCount(0));
               
                while((obj.high<obj.half) || (obj.low>= obj.half) || ((obj.low>= obj.firstQuarter)&&(obj.high<obj.thirdQuarter)) )
                    if(obj.low>= obj.half)
                        obj.value = obj.value-obj.half;
                        obj.low = obj.low-obj.half;
                        obj.high = obj.high-obj.half; 
                    elseif((obj.low>= obj.firstQuarter)&&(obj.high<obj.thirdQuarter))
                        obj.value = obj.value-obj.firstQuarter;
                        obj.low = obj.low-obj.firstQuarter;
                        obj.high = obj.high-obj.firstQuarter; 
                    end

                    obj.low = bitand(bitshift(obj.low,1),obj.codewordMask);
                    obj.high = bitand(bitshift(obj.high,1),obj.codewordMask)+1;
                    
                    nb = obj.nextBit();  
                    if(nb == -1)
                        %I think this might actually work. 
                        %high and low don't depend on the next bits.
                        %need to shift in someting into value or do
                        %something. 
                        obj.value = bitand(bitshift(obj.value,1),obj.codewordMask);%shift in dummy zeros 
                    else
                        obj.value = bitand(bitshift(obj.value,1),obj.codewordMask)+nb;
                    end
                end

                symbol = symbolIdx-1;
            else
                symbol = -1;
            end
            
        end
        
        %i think this is fixed
        %precondition, we have at least one bit in the buffer
        function nextBit = nextBit(obj)

            %this is fucked up
            if(isempty(obj.buff))
                nextBit = -1;
            else
                nextBit = uint32(obj.buff(1));
                obj.buff = obj.buff(2:end);
            end
            
            
        end
        
        %function symbol =  decodeLast(obj)
            
          %  obj.bitsInValue = obj.wordSize;
         %   symbol =  obj.decodeSymbol();
            
        %end
        
        
            
    end
    
    
end