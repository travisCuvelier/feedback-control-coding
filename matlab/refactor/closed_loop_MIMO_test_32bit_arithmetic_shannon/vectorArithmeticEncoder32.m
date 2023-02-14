classdef vectorArithmeticEncoder32 < handle
   
    properties(Constant)
        
        wordSize = 16;
        precision = 32;
        codewordMask = uint32(2^16-1);
        %obj.maxDenominator =  bitshift(uint32(2^obj.wordSize),-2)-1;    %2(# of symbols)+maxSymbolUpToIncludingTimei+1 can equal this.
        %obj.nearMiss = ((obj.maxDenominator-1)/8)*7; %heuristic: don't send any

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
        bitsToFollow 
        cutoff %if symbol > cutoff send 0, then send an elias coded integer
        low
        high
        bidx
        buff
        file
    end
    
    methods(Static=true)
        
        %big endian binary expansion of z (assumed column) given bytewidth.
        function ze = binaryExpand(z,bytewidth)
            ze = zeros(numel(z),bytewidth);
            
            for idx = 1:bytewidth
                ze(:,bytewidth+1-idx) = mod(z,2);
                z = z - ze(:,bytewidth+1-idx);
                z = z/2;
            end
        end
        
        %this is like bi2de(,'left-msb') in the communications toolbox.
        function d = binary2decimal(b)
            
            [~,nc] = size(b);
            
            d = sum((2.^((nc-1):-1:0)).*b,2);
            
        end %the rate of the code in bits/channel use
        
    end
    
    methods
        %constructor
        function obj = vectorArithmeticEncoder32(modelManager)
            obj.topValue = bitshift(uint32(1),obj.wordSize)-1;%have to modify by hand
            obj.firstQuarter = bitshift(obj.topValue,-2)+1;
            obj.half = bitshift(obj.firstQuarter,1);
            obj.thirdQuarter = obj.half+obj.firstQuarter;
            obj.low = uint32(0);
            obj.high = obj.topValue; 
            obj.bitsToFollow = uint32(0); 
            obj.buff = []; 
            obj.modelManager = modelManager; 
            obj.dimensions = obj.modelManager.dimensions; 
            obj.maxSymbolPerDimension = obj.modelManager.maxSymbolPerDimension;
            obj.nSymbolsPerDimension = obj.modelManager.nSymbolsPerDimension;
        end
        
        function newBits = encodeTupleAndUpdateModel(obj,symbolTuple)
            newBits = []; 
            for idx = 1:(obj.dimensions-1)
                model = obj.modelManager.getModel(idx,symbolTuple(1:(idx-1)));
                newBits = [newBits, obj.encodeSymbol(symbolTuple(idx),model,false) ];
                model.updateModel(symbolTuple(idx));
            end
            model = obj.modelManager.getModel(obj.dimensions,symbolTuple(1:(obj.dimensions-1)));
            newBits = [newBits, obj.encodeSymbol(symbolTuple(obj.dimensions),model,true) ];
            model.updateModel(symbolTuple(obj.dimensions));
                       %reset encoder after each tuple
            obj.topValue = bitshift(uint32(1),obj.wordSize)-1;%have to modify by hand
            obj.firstQuarter = bitshift(obj.topValue,-2)+1;
            obj.half = bitshift(obj.firstQuarter,1);
            obj.thirdQuarter = obj.half+obj.firstQuarter;
            obj.low = uint32(0);
            obj.high = obj.topValue; 
            obj.bitsToFollow = uint32(0); 
            obj.buff = []; 
        end
        
        function newBits = encodeSymbol(obj,symbol,model,lastSymbol)
            
            obj.buff = [];
            
            symbolIdx = symbol+1; 
            
            range = (obj.high-obj.low)+1; %this is in 32 bits so it won't overflow; 
        
            obj.high = obj.low+idivide((range*(model.cumCount(symbolIdx-1))),model.cumCount(0))-1;
         
            obj.low = obj.low + idivide((range*(model.cumCount(symbolIdx))),model.cumCount(0));
      

            while((obj.high<obj.half)||(obj.low>= obj.half)||((obj.low >= obj.firstQuarter) && (obj.high<obj.thirdQuarter)))
                
                if(obj.high<obj.half)
                    obj.bitPlusFollow(false);
                elseif(obj.low>= obj.half)
                    obj.bitPlusFollow(true);
                    obj.low = obj.low - obj.half;
                    obj.high = obj.high - obj.half; 
                elseif( (obj.low >= obj.firstQuarter) && (obj.high<obj.thirdQuarter))
                    obj.bitsToFollow = obj.bitsToFollow+1;
                    obj.low = obj.low-obj.firstQuarter;
                    obj.high = obj.high-obj.firstQuarter; 
                end
                %i don't think these masking operations are necessary
                %debugging likelily culprit.
                obj.low  = bitshift(obj.low,1);
                obj.high = bitshift(obj.high,1)+1;
            end 
            
            if(lastSymbol)
                obj.endEncoding();
            end
            
            newBits = obj.buff;
            
        end
        
        %precondition buffer is not full
        function bitPlusFollow(obj,bit)
   
            obj.buff= [obj.buff, bit];
            
            while(obj.bitsToFollow > 0)
                
                obj.buff= [obj.buff, ~bit];
                
                obj.bitsToFollow = obj.bitsToFollow-1;
            end 
        end
        
        function endEncoding(obj)%worried about this. 
            
            obj.bitsToFollow = obj.bitsToFollow+1;
            
            if (obj.low < obj.firstQuarter)
                bitPlusFollow(obj,false)
            else
                bitPlusFollow(obj,true)
            end
            
        end
            
            
    end
    
    
end