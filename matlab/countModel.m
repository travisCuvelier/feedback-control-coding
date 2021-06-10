classdef countModel < handle 
    %UNTITLED2 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = private, GetAccess = public)
       

    end
    
    properties(Constant) 
      X = sparse([0 1; 1 0]);
      Z =sparse([1 0; 0 -1]);
      I = speye(2);
      Y = sparse([0 -1i; 1i 0]);
      H = [1 1; 1 -1]/sqrt(2);
      PL0 = sparse([1 0]'*[1 0]);
      PL1 = sparse([0 1]'*[0 1]);
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
        function obj = countModel()
            maxSymbol = 0;
            wordSize = 16;
            precision = 32;
            denominator = uint32(1);%for time i+1, 2(# of symbols)+maxSymbolUpToIncludingTimei+1
            maxDenominator = uint64(2^32-1);%give me some bandwidth. 
            maxNumerator = uint64(bitshift(uint32(2^wordSize-1),-2)-uint32(1));
            demoninatorClose = bitshift(maxDenominator,-1);
            numeratorClose = bitshift(maxNumerator,-1); 
            maxBins = maxNumerator; %have to watch this
                                    %the number of bins is more than the
                                    %denominator by the KT condition.   
            binsClose = numeratorClose; 
            numUpdates  = uint64(0);
            
            %by making these limits we can deal with both of these cases
            %seperately since 2(# of symbols)+maxSymbolUpToIncludingTimei+1
            updatesLimit = uint64(2^30-1);
            symbolLimit = unint64(2^31);
            stopAddingSymbols = false; 
            
        end 
        
        function updateModel(obj,symbol)
            
            obj.numUpdates = obj.numUpdates+1;
            %checkDenominatorFirst
            %could cause problems if symbol > 2^64-1
            if(symbol >= symbolLimit)
                obj.numUpdates = obj.numUpdates-1; %do nothing
                return                             %don't update model
                                                   %have to use a fano
                                                   %elias code for this. 
            elseif(obj.numUpdates>=obj.updatesLimit)
            
            
            else   
                
            end
            
            obj.numUpdates = obj.numUpdates+1; 
            
            if(symbol > obj.maxSymbol)
                
                
                
                maxSymbol = symbol;
                if(maxSymbol > binsClose)
                    
                end
                    
        
            end
        
        end

end 
