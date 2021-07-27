classdef countModel32 < handle, matlab.mixin.Copyable
    
    properties (SetAccess = public, GetAccess = public)
        total_iterations
        maxSymbol
        counts
        ktCDF
        maxDenominator
        nearMiss 
        symbolLimit
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
        function obj = countModel32()
            obj.total_iterations = uint32(0);
            obj.maxSymbol = uint32(0);
            obj.counts =  [uint32(1)];
            obj.ktCDF = [uint32(1),0];
            obj.maxDenominator =  bitshift(uint32(2^obj.wordSize),-2)-1;    %2(# of symbols)+maxSymbolUpToIncludingTimei+1 can equal this.
            obj.nearMiss = ((obj.maxDenominator-1)/8)*7; %heuristic: don't send any
            %maximum that would push you
            %over this limit rescale
            %counts when you hit this.
            obj.symbolLimit = (obj.nearMiss/8); %arbitrary, must be less than
            %2^precision-3. check me.
        end
        
        %precondition: current model is valid.
        %e.g. denominator is below near miss.
        
        function updateModel(obj,symbol)
            
       
            if(symbol > obj.symbolLimit || symbol == 0)
                
                %do nothing if 0 or over the limit
                
               
            elseif((symbol > obj.maxSymbol) && (obj.nearMiss-obj.ktCDF(1) > (symbol-obj.maxSymbol)+2))%no overflow but increase number of symbols
                    
                    %update model "like normal"
                    %counts has dimension oldMaxSymbol+1;
                    obj.counts(symbol+1) = 1; %automatically fills in zero
                    %in between oldMaxSymbol and
                    %symbol
                    obj.ktCDF(symbol+2)  = 0; %for witten's convention
                    obj.ktCDF(symbol+1)  = 3; %2*counts+1
                    %put increment the cumulative count by 1
                    for idx = symbol:-1:(obj.maxSymbol+2)%be really cautious with this
                        
                        obj.ktCDF(idx) = 1+obj.ktCDF(idx+1);
                        
                    end
                    obj.ktCDF(1:(obj.maxSymbol+1)) = obj.ktCDF(1:(obj.maxSymbol+1))+obj.ktCDF(obj.maxSymbol+2);
                    obj.maxSymbol = symbol;
                    obj.total_iterations = obj.total_iterations+1;
                    
            elseif((symbol <= obj.maxSymbol) && (obj.nearMiss-obj.ktCDF(1) > 2))%no overflow, don't increase number of symbols
                obj.counts(symbol+1) = obj.counts(symbol+1)+1;
                obj.ktCDF(1:(symbol+1)) =  obj.ktCDF(1:(symbol+1))+2; 
                obj.total_iterations = obj.total_iterations+1;
                    
            else
                overflowMaxAndIterations(obj); 
                %no distinction in "overflow types"
            end
      
            
        end
        
        function overflowMaxAndIterations(obj)
            
            %try to get away from using counts probably
            
            while(obj.counts(obj.maxSymbol+1) > 0)
                obj.counts = bitshift(obj.counts,-1);
            end
            
            obj.counts(1) = 1;
            
            idx = obj.maxSymbol;
            
            while(obj.counts(idx) ==0)
                idx = idx-1;
            end
            
            obj.counts = obj.counts(1:idx);
            obj.total_iterations = sum(obj.counts);
            
            obj.maxSymbol = idx-1;
            
            obj.ktCDF = zeros(size(obj.counts));
            obj.ktCDF(obj.maxSymbol+1) = 2*obj.counts(obj.maxSymbol+1)+1;
            
            for idx = (obj.maxSymbol):-1:1
                
                obj.ktCDF(idx) = obj.ktCDF(idx+1)+2*obj.counts(idx)+1;
                
            end
            obj.ktCDF(end+1) = 0; %mildly inefficient. for witten's
                                  %convention
        end
        
        %gives it in wittens convention. 
        function c = cumCount(obj,idx)
            if(idx <= (obj.maxSymbol+1))
                c = obj.ktCDF(idx+1);
            else
                error('error line 146');
            end
        end
            
            
    end
end 

