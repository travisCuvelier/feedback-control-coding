classdef arithmeticDecoder32 < handle
   
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
        file
        value
        bitsInBuffer
    end
    
    
    methods
        %constructor
        function obj = arithmeticDecoder32(model,fileName)
            obj.topValue = bitshift(uint32(1),obj.wordSize)-1;%have to modify by hand
            obj.firstQuarter = bitshift(obj.topValue,-2)+1;
            obj.half = bitshift(obj.firstQuarter,1);
            obj.thirdQuarter = obj.half+obj.firstQuarter;
            obj.low = uint32(0);
            obj.high = obj.topValue; 
            obj.model  = model;
            %warning('The encoder updates the model as it encodes, ensure that the model you pass in is "new" and initialized the same as with the encoder. DO NOT PASS IN THE ENCODER MODEL HANDLE');
            obj.file = fopen(fileName,'r');
            obj.value = uint32(fread(obj.file,1,'uint16'));
            obj.buff =  uint16(fread(obj.file,1,'uint16'));%this outer cast
            if(isempty(obj.buff))                          %is actually reqd                                                         %required.
               obj.buff =  uint16(0);  
            end                                             
            obj.bitsInBuffer = obj.wordSize; 
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
        
        %precondition, we have at least one bit in the buffer
        function nextBit = nextBit(obj)
            %mask the next bit in the buffer via
            %mnb = bitand(uint16(2^(obj.bitsInBuffer-1)),obj.buff)
            %shift to position  
            %nextBit = bitshift(mnb,-(obj.bitsInBuffer-1)
            %refill buffer if its empty. 
            
            nextBit = uint32(bitshift(bitand(uint16(2^(obj.bitsInBuffer-1)),obj.buff),(1-obj.bitsInBuffer)));
            obj.bitsInBuffer = obj.bitsInBuffer-1;
            if(obj.bitsInBuffer == 0)
                obj.buff =  uint16(fread(obj.file,1,'uint16'));
                if(isempty(obj.buff))                        
                    obj.buff =  uint16(0);  
                end    
                %need to handle if this doesn't work!
                obj.bitsInBuffer = obj.wordSize;
            end
        end
            
            
    end
    
    
end