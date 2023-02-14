classdef shannonEncoder32 < handle
   
    properties(Constant)
        
        wordSize = 16;
        precision = 32;
        codewordMask = uint32(2^16-1);

    end
    
    properties (SetAccess = public, GetAccess = public)
        model
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
        function obj = shannonEncoder32(model)
            obj.model  = model;         
        end
        
        function codeword = encodeSymbol(obj,symbol)
            
            sidx = obj.model.getLinearIdxFromSymbolTuple(symbol);
            
            %note: We will not overflow precision so long as 
            %obj.model.strictCDF(obj.model.nSymbols+1)*2^wordsize <=
            %(2^precision-1). If the counts are stored in a variable the
            %same size as wordsize, we will satisfy this constraint. 
     
            tag = idivide((obj.model.strictCDF(sidx)*(obj.codewordMask+1)),obj.model.strictCDF(obj.model.nSymbols+1));
            
            
            %An easy underflow limit for this calculation is that the total
            %number of counts (obj.model.strictCDF(obj.model.nSymbols+1))
            %cannot exceed 2^(wordsize). Easy to satisfy this if the we
            %store counts in a wordsize size random variable. 
            
            prob = idivide(((obj.model.strictCDF(sidx+1)-obj.model.strictCDF(sidx))*(obj.codewordMask+1)),obj.model.strictCDF(obj.model.nSymbols+1));
            
            %I believe this code is safe so long as
            %obj.model.strictCDF(obj.model.nSymbols+1) is less than or
            %equal to 2^wordsize-1. 
            
            bitsToKeep = 0;
            sufficientlySmall = false; 
            while( ~(sufficientlySmall) && (bitsToKeep < obj.wordSize))
                bitsToKeep = bitsToKeep+1; 
                premask = uint32(2^(obj.wordSize-bitsToKeep)-1); 
                mask = bitand(bitcmp(premask),obj.codewordMask);
                floored = bitand(mask,tag);
                upper = (floored+premask+1);
                %assume that prob (above) does not underflow. 
                %if bits to keep (after update on top line of the loop
                %is equal to the word size, then premask is zero, floored
                %equals the tag, and upper equals tag+1. tag+1 will not
                %overflow precision so long as the precision is at least
                %one bit greater than wordsize. 
                sufficientlySmall = ((upper-floored)<=prob);
            end 
            
            expansion = shannonEncoder32.binaryExpand(floored,obj.wordSize);
            codeword= expansion(1:bitsToKeep);
            
        end        
            
    end
    
    
end