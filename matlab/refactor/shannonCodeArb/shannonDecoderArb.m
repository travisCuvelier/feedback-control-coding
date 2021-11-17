classdef shannonDecoderArb < handle
   

    
    properties (SetAccess = public, GetAccess = public)
        model
        encoder
        buffer
        wordSize
        precision
        codewordMask
        cwMaskPlusOne
        
    end
    
    
    methods
        %constructor
        function obj = shannonDecoderArb(model,precision)
            obj.precision = precision;
            obj.wordSize = floor(precision/2);
            
            obj.codewordMask =  uintarb(precision, [uint32(1)],false);
            for dummy = 2:1:obj.wordSize
                obj.codewordMask = obj.codewordMask.leftShift(1)+uintarb(precision, [uint32(1)],false);
            end
            obj.cwMaskPlusOne = obj.codewordMask+uintarb(precision,[1],false);
            
            obj.model  = model;
            
            if(model.precision~=precision)
                error('model precision must be the same as the decoder precision')
            end
            
            obj.buffer = [];
          
            obj.encoder = shannonEncoderArb(model,precision);
            %fix fields 
        end
        
        function symbol = decodeCodeword(obj,bits)
            nbits = numel(bits);
            if(nbits > obj.wordSize)
                error('This function doesn''t decode streams.')
            end
            
            tag = uintarb(obj.precision,[0],false);
            
            for bidx = 1:nbits
                dummy = uintarb(obj.precision,bits(bidx));
                tag = tag+dummy.leftShift(obj.wordSize-bidx);
            end
            
            
            sidx = 1;
            while(downCast(obj.model.strictCDF(sidx).*(obj.cwMaskPlusOne),obj.precision)./(obj.model.strictCDF(obj.model.nSymbols+1))<tag)
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
                    %fprintf('I ran this way')
                    symbol = symbolA;
                else
                   %fprintf('I ran that way')

                    symbol = obj.model.getSymbolFromIdx(sidx);
                end
                                
            end
                  
        end
     
 
            
            
    end
    
    
end