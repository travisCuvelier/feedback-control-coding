classdef shannonDecoder32 < handle
   
    properties(Constant)
        wordSize = 16;
        precision = 32;
        codewordMask = uint32(2^16-1)
        
    end
    
    properties (SetAccess = public, GetAccess = public)
        model
        encoder
        buffer
    end
    
    
    methods
        %constructor
        function obj = shannonDecoder32(model)
            obj.model  = model;
            obj.buffer = [];
            obj.encoder = shannonEncoder32(model);
            %fix fields 
        end
        
        function symbol = decodeCodeword(obj,bits)
            nbits = numel(bits);
            if(nbits > obj.wordSize)
                error('This function doesn''t decode streams.')
            end
            
            tag = uint32(0);
            
            for bidx = 1:nbits
                tag = tag+bitshift(uint32(bits(bidx)),obj.wordSize-bidx);
            end
            
            sidx = 1;
            while(idivide((obj.model.strictCDF(sidx)*(obj.codewordMask+1)),obj.model.strictCDF(obj.model.nSymbols+1))<tag)
                sidx = sidx+1;
            end
            
            if(sidx == 1)
                symbol = obj.model.getSymbolFromIdx(1);
            elseif(sidx  == obj.model.nSymbols+1)
                symbol = obj.model.getSymbolFromIdx(obj.model.nSymbols);
            else
                symbolA = obj.model.getSymbolFromIdx(sidx-1);
                %symbolB = obj.model.getSymbolFromIdx(sidx);
           
                %symbols A and B are candidates. Symbol A must have a
                %shorter codeword length than symbol B. Thus, since by the
                %prefix-free constraint we know that the vector of  input
                %bits contains at least as many elements as the following:
                candidateA = obj.encoder.encodeSymbol(symbolA);
                if(isequal(bits(1:length(candidateA)),candidateA))
                    symbol = symbolA;
                else
                    symbol = obj.model.getSymbolFromIdx(sidx);
                end
                                
            end
                  
        end
     
 
            
            
    end
    
    
end