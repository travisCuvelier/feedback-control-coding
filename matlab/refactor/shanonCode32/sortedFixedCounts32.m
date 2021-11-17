classdef sortedFixedCounts32 < handle
    %UNTITLED2 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = public, GetAccess = public)
        total_iterations
        strictCDF
        counts
        maxDenominator 
        nSymbols
        perm
        iperm
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
        function obj = sortedFixedCounts32(counts)
        
            obj.total_iterations = uint32(0);
            obj.maxDenominator = uint32(2^obj.wordSize)-1;%This is the biggest
            obj.nSymbols = numel(counts);
            
            if(obj.nSymbols > obj.maxDenominator/2)
                error('your precision is probably too low for this many symbols');
            end
            
            obj.counts = uint32(counts);
            if(sum(obj.counts<0))
                error('counts must be nonnegative\n');
            end
            obj.counts(obj.counts==0)=uint32(1); 
            obj.perm = 1:(obj.nSymbols+1);
            [obj.counts,b] = sort(obj.counts,'descend');
            obj.perm = obj.perm(b);
            
            for idx = 1:obj.nSymbols
                obj.iperm(obj.perm(idx))=idx;
            end
            
            obj.strictCDF = zeros(1,obj.nSymbols+1);
            obj.strictCDF(1) = 0; 
            for idx = 2:(obj.nSymbols+1)
               obj.strictCDF(idx) = obj.strictCDF(idx-1)+obj.counts(idx-1); 
               if(~(intmax('uint32')-obj.counts(idx-1)>=obj.strictCDF(idx-1)))
                   error('integer overflow');
               end
            end
            
            if(obj.strictCDF(end)>obj.maxDenominator)
                error('must rescale counts first so that sum(counts) < maximumum denominator\n');
            end

        end
        
        %precondition: current model is valid.
        %e.g. denominator is below near miss.
        function updateModel(obj,symbol,varargin)
            
            obj.total_iterations=obj.total_iterations+1;
            
            symbolIdx = obj.getIdxFromSymbol(symbol);
            obj.counts(symbolIdx) = obj.counts(symbolIdx)+1;
            
            if((obj.strictCDF(end)+uint32(1))>=obj.maxDenominator)%think can be equality
                k = 0;
                top = obj.strictCDF(end)+uint32(1)-uint32(obj.nSymbols);
                while(top+uint32(obj.nSymbols) >= obj.maxDenominator)%think can be equality
                    k = k-1;
                    top = bitshift(top,-1);
                end
                obj.counts = obj.counts-1;
                obj.counts = bitshift(obj.counts,k);
                obj.counts = obj.counts+1;
            end
            
            [obj.counts,newperm] = sort(obj.counts,'descend');%not efficient but who cares. 
            obj.strictCDF(1) = 0; 
            for idx = 2:(obj.nSymbols+1)
                obj.strictCDF(idx) = obj.strictCDF(idx-1)+obj.counts(idx-1); 
                if(~(intmax('uint32')-obj.counts(idx-1)>=obj.strictCDF(idx-1)))
                    error('integer overflow');
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

