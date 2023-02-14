classdef sortedAdaptiveCountsVariableCutoffs64 < handle
         
    %UNTITLED2 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = public, GetAccess = public)
        total_iterations
        strictCDF
        counts %actual number of symbols
        maxDenominator 
        nSymbols
        nSymbolsPerDim
        nDims
        perm
        iperm
    end
    
    properties(Constant)
        wordSize = 32; %cdf cannot exceed 2^wordSize-1
        precision = 64;     
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
        function obj = sortedAdaptiveCountsVariableCutoffs64(counts,biggestSymbolPerDimension)

            if(~isrow(counts))
                counts = counts.';
                if(~isrow(counts))
                    error('counts should be a one dimensional array')
                end
            end

             obj.nSymbols = numel(counts);
            if(obj.nSymbols~=prod(biggestSymbolPerDimension+1)) %counts must have a count for each combo of positive natural symbols and also combinations of overflows (0)
                error('pidgeon hole issue');
            end

        
            obj.total_iterations = uint64(0);
            obj.maxDenominator = uint64(2^obj.wordSize)-1;%This is the biggest
            obj.nSymbolsPerDim = biggestSymbolPerDimension+1;
            obj.nDims = length(obj.nSymbolsPerDim);
            if(obj.nSymbols > obj.maxDenominator/2)
                error('your precision is probably too low for this many symbols');
            end
            
            obj.counts = uint64(counts);
            if(sum(obj.counts<0))
                error('counts must be nonnegative\n');
            end
            obj.counts(obj.counts==0)=uint64(1); 
            obj.perm = 1:(obj.nSymbols);
            [obj.counts,b] = sort(obj.counts,'descend');
            obj.perm = obj.perm(b);
            for idx = 1:obj.nSymbols
                obj.iperm(obj.perm(idx))=idx;
            end
            
            obj.strictCDF = uint64(zeros(1,obj.nSymbols+1));
            obj.strictCDF(1) = uint64(0); %superfluous here
            obj.strictCDF(2:(obj.nSymbols+1)) = cumsum(obj.counts);

            if(obj.strictCDF(end)>obj.maxDenominator)
                error('must rescale counts first so that sum(counts) < maximumum denominator\n');
            end

        end
        
        %precondition: current model is valid.
        %e.g. denominator is below near miss.
        function updateModel(obj,symbol,varargin)
            
            obj.total_iterations=obj.total_iterations+1;
            
            symbolIdx = obj.getLinearIdxFromSymbolTuple(symbol);

            obj.counts(symbolIdx) = obj.counts(symbolIdx)+1;
            
            if((obj.strictCDF(end)+uint64(1))>=obj.maxDenominator)%think can be equality
                k = 0;
                top = obj.strictCDF(end)+uint64(1)-uint64(obj.nSymbols);
                while(top+uint64(obj.nSymbols) >= obj.maxDenominator)%think can be equality
                    k = k-1;
                    top = bitshift(top,-1);
                end
                obj.counts = obj.counts-1;
                obj.counts = bitshift(obj.counts,k);
                obj.counts = obj.counts+1;
            end
            
            [obj.counts,newperm] = sort(obj.counts,'descend');%not efficient but who cares. 
            obj.strictCDF(1) = uint64(0); 
            obj.strictCDF(2:(obj.nSymbols+1)) = cumsum(obj.counts);
            obj.perm = obj.perm(newperm);
            obj.iperm(obj.perm) = 1:obj.nSymbols;
        end
        
        %next step- rewrite sub2ind, ind2sub so that they are more
        %efficient and memoize. 
        function linearIdx = getLinearIdxFromSymbolTuple(obj,symbol)
           dummy = num2cell(symbol+1);
           indexTuple = sub2ind(obj.nSymbolsPerDim, dummy{:});
           linearIdx = obj.iperm(indexTuple);  
        end
        
        function symbol = getSymbolTupleFromLinearIdx(obj,linearIdx)
           linearIdx = obj.perm(linearIdx);
           dummy = cell(1,obj.nDims);
           [dummy{:}] = ind2sub(obj.nSymbolsPerDim,linearIdx);
           indexTuple = cell2mat(dummy);
           symbol = indexTuple-1;
        end
             
             
    end
end 

