classdef shannonEncoderArb < handle

    properties (SetAccess = public, GetAccess = public)
        model
        wordSize 
        precision 
        codewordMask
        cwMaskPlusOne
        bitMasks 
        %This script does not update the model. 
    end
    
    methods(Static=true)
        
        %big endian binary expansion of z (assumed column) given bytewidth.
        function ze = binaryExpand(z,bytewidth)
            ze = zeros(numel(z),bytewidth);
            
            for idx = 1:bytewidth
                ze(:,bytewidth+1-idx) = mod(z,2);
                z = z - ze(:,bytewidth+1-idx);
                z = bitshift(z,-1);
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
        function obj = shannonEncoderArb(model,precision)
            obj.model  = model;         
            obj.precision = precision; 
            obj.wordSize = floor(precision/2); 
            obj.codewordMask =  uintarb(precision, [uint32(0)],false);
            obj.bitMasks = {};%these are fucked up.
            for dummy = 1:1:obj.wordSize
                obj.bitMasks{obj.wordSize+1-(dummy)} = upCast(downCast(not(obj.codewordMask),obj.wordSize),obj.precision);
                obj.codewordMask = obj.codewordMask.leftShift(1)+uintarb(precision, [uint32(1)],false);
            end
            obj.cwMaskPlusOne=obj.codewordMask+uintarb(precision, [uint32(1)],false);
        end
        
        function codeword = encodeSymbol(obj,symbol)
            sidx = obj.model.getIdxFromSymbol(symbol);
            
            %note: We will not overflow precision so long as 
            %obj.model.strictCDF(obj.model.nSymbols+1)*2^wordsize <=
            %(2^precision-1). If the counts are stored in a variable the
            %same size as wordsize, we will satisfy this constraint. 
     
            
            tag = downCast((obj.model.strictCDF(sidx).*(obj.cwMaskPlusOne))./(obj.model.strictCDF(obj.model.nSymbols+1)),obj.precision);
            
            
            %An easy underflow limit for this calculation is that the total
            %number of counts (obj.model.strictCDF(obj.model.nSymbols+1))
            %cannot exceed 2^(wordsize). Easy to satisfy this if the we
            %store counts in a wordsize size random variable. 
            num = downCast((obj.model.strictCDF(sidx+1)-obj.model.strictCDF(sidx)).*obj.cwMaskPlusOne,obj.precision);
            
            prob = downCast(num./obj.model.strictCDF(obj.model.nSymbols+1),obj.precision);
            
            %I believe this code is safe so long as
            %obj.model.strictCDF(obj.model.nSymbols+1) is less than or
            %equal to 2^wordsize-1. 
            
            bitsToKeep = 0;
            sufficientlySmall = false; 
            while( ~(sufficientlySmall) && (bitsToKeep < obj.wordSize))
                bitsToKeep = bitsToKeep+1; 
                floored = and(obj.bitMasks{bitsToKeep},tag);         
                upper = floored+upCast(downCast(not(obj.bitMasks{bitsToKeep}),obj.wordSize),obj.precision)+uintarb(obj.precision,[uint32(1)],false);%I think this works
                %assume that prob (above) does not underflow. 
                %if bits to keep (after update on top line of the loop
                %is equal to the word size, then premask is zero, floored
                %equals the tag, and upper equals tag+1. tag+1 will not
                %overflow precision so long as the precision is at least
                %one bit greater than wordsize. 
                
                sufficientlySmall = ((upper-floored)<=prob);
            end 
            shorter = downCast(floored,obj.wordSize);
            codeword = shorter.getMSBs(bitsToKeep);
        end        
            
    end
    
    
end