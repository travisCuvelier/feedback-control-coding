classdef cuttoffCounts32 < handle
    %UNTITLED2 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = public, GetAccess = public)
        total_iterations
        maxSymbol
        myCDF %(myCDF(i) = sum_{j>=i}counts(i)) if 
        maxDenominator
        nearMiss 
        symbolLimit
        lop
    end
    
    properties(Constant)
        wordSize = 16;
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
        function obj = cuttoffCounts32(cutoff)
            obj.total_iterations = uint32(0);
            obj.maxDenominator =  bitshift(uint32(2^obj.wordSize),-2)-1;    %2(# of symbols)+maxSymbolUpToIncludingTimei+1 can equal this.
            obj.nearMiss = ((obj.maxDenominator-1)/8)*7; %heuristic: don't send any
            %maximum that would push you
            %over this limit rescale
            %counts when you hit this.
            
            if(cutoff>obj.nearMiss)
                error('your cuttoff is (almost) too numerically large, your model will be almost incompressible')
            end
            obj.lop = uint32((cutoff+1):-1:0);
            obj.myCDF = obj.lop;
            obj.symbolLimit = cutoff;
        end
        
        %precondition: current model is valid.
        %e.g. denominator is below near miss.
        function updateModel(obj,symbol)
            
            if(symbol > obj.symbolLimit)
                symbol = 0;  
            end
            
            if(obj.nearMiss-obj.myCDF(1)>1)
                obj.myCDF(1:(symbol+1)) = obj.myCDF(1:(symbol+1))+1;
            else
                obj.myCDF = bitshift((obj.myCDF-obj.lop),-1);
                
                %if input myCDF is valid, this one is definitely valid since lop subtracts one symbol from every frequency
                obj.myCDF(1:(symbol+1)) = obj.myCDF(1:(symbol+1))+1;
                
                while( (obj.nearMiss - obj.myCDF(1)) <= obj.lop(1) )%lee is important. check other model
                    obj.myCDF =  bitshift(obj.myCDF,-1); 
                end 
                
                obj.myCDF = obj.myCDF+obj.lop;
                
            end
            
        end
        
        function c = cumCount(obj,idx)
            if(idx <= (obj.symbolLimit+1))
                c = obj.ktCDF(idx+1);
            else
                error('error line 146');
            end
        end
        
        
            
            
    end
end 

