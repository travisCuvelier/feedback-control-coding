classdef sortedFixedCountsArb < handle
    %UNTITLED2 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = public, GetAccess = public)
        wordSize
        precision     
        total_iterations
        strictCDF
        counts
        maxDenominator 
        nSymbols
        perm
        iperm
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
        function obj = sortedFixedCountsArb(counts,precision)
            obj.precision = precision;
            obj.wordSize = floor(precision/2); 
            obj.total_iterations = 0;

            obj.maxDenominator = uintarb.maximumValue(obj.wordSize);
            obj.maxDenominator = obj.maxDenominator.upCast(precision);  
            
            obj.nSymbols = numel(counts);
            if(obj.nSymbols >intmax('uint32'))
                error('number of symbols needs to be less than 2^32-1 for now...');
            elseif(log2(obj.nSymbols)<floor(precision/4))
                error('too many symbols for precision');
            end
            obj.counts = uintarb.empty();
            for idx = 1:obj.nSymbols
                if(counts(idx)<0 || counts(idx)>intmax('uint32'))
                    error('counts must be nonnegative and initializiation cannot exceed maximum 32 bit integer size. \n');
                end
                if(counts(idx)==0)
                    obj.counts(idx) = uintarb(precision,[uint32(1)],true);
                else
                    lastwarn('');
                    obj.counts(idx)= uintarb(precision,[uint32(counts(idx))],false);
                    if(strcmp(lastwarn,'Overflow (word level)')||strcmp(lastwarn,'Overflow (bit level)'))
                        error('Your intitialization overflowed precision.')
                    elseif(obj.counts(idx)>obj.maxDenominator)
                        error('Accumulation of counts must be stored in floor(precision/2) bits. One of your counts blew this bound.')
                    end
                end
            end
                         
            obj.perm = 1:(obj.nSymbols+1);
            [obj.counts,b] = uintarb.descendingQuicksort(obj.counts);
            obj.perm = obj.perm(b);
           
            for idx = 1:obj.nSymbols
                obj.iperm(obj.perm(idx))=idx;
            end
            
            obj.strictCDF = uintarb.empty();
            obj.strictCDF(1) = uintarb(precision,[uint32(0)],true);
            
            for idx = 2:(obj.nSymbols+1)
               obj.strictCDF(idx) = obj.strictCDF(idx-1)+obj.counts(idx-1); 
               %we know that every count is less than
               %uintarb.maximumValue(wordSize) == obj.maxDenominator
               if(~(obj.maxDenominator-obj.counts(idx-1)>=obj.strictCDF(idx-1)))
                   error('Accumulation of counts must be stored in floor(precision/2) bits. Your individual counts didn''t blow this bound, but the accumulation did.');
               end
            end
            
        end
        
        %precondition: current model is valid.
        %e.g. denominator is below near miss.
        function updateModel(obj,symbol,varargin)
            
            obj.total_iterations=obj.total_iterations+1;
            
            symbolIdx = obj.getIdxFromSymbol(symbol);
            obj.counts(symbolIdx) = obj.counts(symbolIdx)+uintarb(obj.precision,[uint32(1)],true);
            
            if((obj.strictCDF(end)+uintarb(obj.precision,[uint32(1)],true))>=obj.maxDenominator)%think can be equality
                k = 0;
                top = obj.strictCDF(end)+uintarb(obj.precision,[uint32(1)],true)-uintarb(obj.precision,[obj.nSymbols],true);
                while((top+uintarb(obj.precision,[obj.nSymbols],false)) >= obj.maxDenominator)%think can be equality
                    k = k+1;
                    top = top.rightShift(1);
                end
                for idx = 1:obj.nSymbols
                    obj.counts(idx) = obj.counts(idx)-uintarb(obj.precision,[1],true);
                    obj.counts(idx) = obj.counts(idx).rightShift(k);
                    obj.counts(idx) = obj.counts(idx)+uintarb(obj.precision,[1],true);
                end
            end
            
            [obj.counts,newperm] = uintarb.descendingQuicksort(obj.counts);%not efficient but who cares. 
            obj.strictCDF(1) = uintarb(obj.precision,[uint32(0)],true);
            for idx = 2:(obj.nSymbols+1)
               obj.strictCDF(idx) = obj.strictCDF(idx-1)+obj.counts(idx-1); 
               %we know that every count is less than
               %uintarb.maximumValue(wordSize) == obj.maxDenominator
               if(~(obj.maxDenominator-obj.counts(idx-1)>=obj.strictCDF(idx-1)))
                   error('Accumulation of counts must be stored in floor(precision/2) bits. During an update, your accumulation blew this limit. This should not happen...');
               end
            end
            
            obj.perm = obj.perm(newperm);
            
            for idx = 1:obj.nSymbols
                obj.iperm(obj.perm(idx))=idx;
            end  
        end
        
        
        function symbolIdx = getIdxFromSymbol(obj,symbol)
           symbolIdx = obj.iperm(symbol+1);  
        end
        
        function symbol = getSymbolFromIdx(obj,symbolIdx)
           symbol = obj.perm(symbolIdx)-1;  
        end
        
             
    end
end 

