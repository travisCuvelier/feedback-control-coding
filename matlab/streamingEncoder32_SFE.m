classdef streamingEncoder32_SFE < handle
   
    properties(Constant)
        
        wordSize = 16;
        precision = 32;
        codewordMask = uint32(2^16-1);
        %obj.maxDenominator =  bitshift(uint32(2^obj.wordSize),-2)-1;    %2(# of symbols)+maxSymbolUpToIncludingTimei+1 can equal this.
        %obj.nearMiss = ((obj.maxDenominator-1)/8)*7; %heuristic: don't send any

    end
    
    properties (SetAccess = public, GetAccess = public)
        model
        topValue
        firstQuarter
        half
        thirdQuarter
        bitsToFollow 
        cutoff %if symbol > cutoff send 0, then send an elias coded integer
        low
        high
        buff
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
        function obj = streamingEncoder32_SFE(model)
            
            obj.topValue = bitshift(uint32(1),obj.wordSize)-1;%have to modify by hand
            obj.firstQuarter = bitshift(obj.topValue,-2)+1;
            obj.half = bitshift(obj.firstQuarter,1);
            obj.thirdQuarter = obj.half+obj.firstQuarter;
            obj.bitsToFollow = uint32(0); 
            obj.model  = model; 
            obj.buff = [];
        
        end
        
        function buffer = getCodeword(obj,symbol)
            
            obj.buff = [];
            obj.low = uint32(0);
            obj.high = obj.topValue; 
            obj.encodeSymbol(symbol);
            obj.endEncoding();
            buffer = obj.buff;
            
        end
        
        function encodeSymbol(obj,symbol)
       
            symbolIdx = symbol+1; 
            
            range = (obj.high-obj.low)+1; %this is in 32 bits so it won't overflow; 
        
            obj.high = obj.low+idivide((range*(obj.model.cumCount(symbolIdx-1))),obj.model.cumCount(0))-1;
         
            obj.low = obj.low + idivide((range*(obj.model.cumCount(symbolIdx))),obj.model.cumCount(0));
      

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
            
        end
        
        %precondition buffer is not full
        function bitPlusFollow(obj,bit)
            bit = logical(bit);
            obj.buff= [obj.buff,bit];            
   
            while(obj.bitsToFollow > 0)          
                obj.buff= [obj.buff,~bit];       
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
            
            %we probably need to autobuffer in decoder.
            
        end
            
            
    end
    
    
end