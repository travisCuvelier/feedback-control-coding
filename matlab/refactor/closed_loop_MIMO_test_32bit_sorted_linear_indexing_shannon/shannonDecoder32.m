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
                %warning('This function doesn''t decode streams. I think this will work for this linear indexing with overflows thing')
                bits = bits(1:obj.wordSize);
                nbits = obj.wordSize; 
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
                symbol = obj.model.getSymbolTupleFromLinearIdx(1);
            elseif(sidx  == obj.model.nSymbols+1)
                symbol = obj.model.getSymbolTupleFromLinearIdx(obj.model.nSymbols);
            else
                symbolA = obj.model.getSymbolTupleFromLinearIdx(sidx-1);
                %symbolB = obj.model.getSymbolTupleFromLinearIdx(sidx);
           
                %symbols A and B are candidates. Symbol A must have a
                %shorter codeword length than symbol B. Thus, since by the
                %prefix-free constraint we know that the vector of  input
                %bits contains at least as many elements as the following:
                candidateA = obj.encoder.encodeSymbol(symbolA);
                if(isequal(bits(1:length(candidateA)),candidateA))
                    symbol = symbolA;
                else
                    symbol = obj.model.getSymbolTupleFromLinearIdx(sidx);
                end
                                
            end
                  
        end
     
 
            
            
    end
    
    
end