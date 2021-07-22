classdef streamingDecoder32 < handle
   
    properties(Constant)
        
        wordSize = 16;
        precision = 32;
        codewordMask = uint32(2^16-1)
        
    end
    
    properties (SetAccess = public, GetAccess = public)
        model
        topValue
        firstQuarter
        half
        thirdQuarter 
        cutoff %if symbol > cutoff send 0, then send an elias coded integer
        low
        high
        buff
        value
        codeword
    end
    
    
    methods
        %constructor
        function obj = streamingDecoder32(model)
            obj.topValue = bitshift(uint32(1),obj.wordSize)-1;%have to modify by hand
            obj.firstQuarter = bitshift(obj.topValue,-2)+1;
            obj.half = bitshift(obj.firstQuarter,1);
            obj.thirdQuarter = obj.half+obj.firstQuarter;
            obj.model  = model;
            warning('The encoder updates the model as it encodes, ensure that the model you pass in is "new" and initialized the same as with the encoder. DO NOT PASS IN THE ENCODER MODEL HANDLE');  
            %fix fields 
        end
        
        function symbol = decodeCodeword(obj,codeword)
            
            obj.codeword = codeword; 
            obj.low = uint32(0);
            obj.high = obj.topValue; 

            if(length(codeword) < obj.wordSize)
                obj.codeword = [codeword, zeros(1,obj.wordSize-length(codeword),'logical')];
            end
            
            obj.value = uint32(0);

            for idx = 1:obj.wordSize
                obj.value = obj.value+bitshift(uint32(obj.codeword(idx)),obj.wordSize-idx);
            end
            obj.codeword = obj.codeword((obj.wordSize+1):end);
            symbol = obj.decodeSymbol;   
            
        end
     
        function symbol =  decodeSymbol(obj)%does not actually even output any bits
     
            range = (obj.high-obj.low)+1; %this is in 32 bits so it won't overflow; Initially should be 2^wordSize
            
            cum = idivide(((obj.value-obj.low+1)*obj.model.cumCount(0)-1),range);%shouldn't overflow but likely culprit

            symbolIdx = 1;
            while(obj.model.cumCount(symbolIdx)>cum)
                symbolIdx = symbolIdx+1;
            end
            obj.high = obj.low + idivide((range*obj.model.cumCount(symbolIdx-1)),obj.model.cumCount(0))-1;
            obj.low =  obj.low + idivide((range*obj.model.cumCount(symbolIdx)),obj.model.cumCount(0));
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
               
                obj.value = bitand(bitshift(obj.value,1),obj.codewordMask)+obj.nextBit();  
            end
           
            symbol = symbolIdx-1;
            
        end
        
        function nextBit = nextBit(obj)
           
            if(isempty(obj.codeword))
                nextBit = uint32(0);
            else
                nextBit = uint32(obj.codeword(1));
                obj.codeword = obj.codeword(2:end);%check this
            end
                        
        end
            
            
    end
    
    
end