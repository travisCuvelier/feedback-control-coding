classdef conditionalCountManager32 < handle
    %UNTITLED2 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = public, GetAccess = public)
        total_iterations
        dimensions
        maxSymbolPerDimension
        countTableus
        nSymbolsPerDimension
    end
    
    properties(Constant)
        wordSize = 16; %cdf cannot exceed 2^wordSize-1
        precision = 32;     
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
        function obj = conditionalCountManager32(maxSymbolPerDimension)

            obj.dimensions = length(maxSymbolPerDimension);
            obj.total_iterations = uint32(0);
            
            obj.maxSymbolPerDimension = maxSymbolPerDimension;
            obj.nSymbolsPerDimension = maxSymbolPerDimension+1;
            
            obj.countTableus{1} = cutoffCounts32(maxSymbolPerDimension(1));

            for didx = 2:obj.dimensions
               tableuSize= prod(obj.nSymbolsPerDimension(1:didx-1)); 
               dummy = cell(tableuSize,1);
               for sidx =  1:tableuSize
                   dummy{sidx} = cutoffCounts32(maxSymbolPerDimension(didx));
               end

               %this is so stupid... reshape "size" must have two elements.
               %dumb...
               if(didx==2)
                   obj.countTableus{didx} = dummy;
               else
                   obj.countTableus{didx} = reshape(dummy,obj.nSymbolsPerDimension(1:didx-1));
               end

            end

        end

        function model = getModel(obj,dim, history)
             if(dim>1)
                historyIdxs = num2cell(obj.getIdxFromSymbol(history));
                model = obj.countTableus{dim}{historyIdxs{:}};
             else
                model = obj.countTableus{1};
             end
        end
        
        function symbolIdx = getIdxFromSymbol(obj,symbol)
           symbolIdx = symbol+1;  
        end
        
        function symbol = getSymbolFromIdx(obj,symbolIdx)
           symbol = symbolIdx-1;  
        end
    end
             
        
            
end 

