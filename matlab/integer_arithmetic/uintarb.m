classdef uintarb %this is a value class
    %NUMBER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        words
        bits
        value
        mask
        topWordBits
    end
    
    methods(Static)
        function [w3,carryOut]  = addword(w1,w2,varargin)
            
            if(isempty(varargin))
                carry = 0;
            else
                carry = varargin{1};
            end
            
            w1 = uint32(w1);
            w2 = uint32(w2);
            msbMask = bitshift(uint32(1),31);
            lsbsMask = bitcmp(msbMask);
            w1_lsbs = bitand(lsbsMask,w1);
            w2_lsbs = bitand(lsbsMask,w2);
            w3 = w1_lsbs+w2_lsbs+carry;
            lsCarry = bitshift(bitand(msbMask,w3),-31);
            w3 = bitand(w3,lsbsMask);
            w1MSB = bitshift(bitand(msbMask,w1),-31);
            w2MSB = bitshift(bitand(msbMask,w2),-31);
            msbSum = lsCarry+w1MSB+w2MSB;
            carryOut = uint32(0);
            if(msbSum == 1)
                w3 =w3+bitshift(uint32(1),31);   
            elseif(msbSum == 2)
                carryOut = uint32(1);
            elseif(msbSum == 3)
                w3 =w3+bitshift(uint32(1),31);
                carryOut = uint32(1);
            end
        end
    end
    methods
        function obj = uintarb(bits,valueWords)
            
            obj.words = ceil(bits/32);
            obj.bits = bits;
            if(length(valueWords)==obj.words)
                obj.value = uint32(valueWords);
            else
                warning('I''m filling in zeros for most significant words');
                obj.value = uint32(zeros(1,obj.words));
                obj.value(((obj.words-length(valueWords))+1):end) = uint32(valueWords);
            end
            
            mask = uint32(0);
            %can make this faster and more efficient.
            for idx = 1:(obj.words*32-bits)
                mask = mask+bitshift(uint32(1),32-idx);                
            end
            obj.mask = bitcmp(mask,'uint32');
            obj.topWordBits = bits- (obj.words-1)*32;
            obj.value(1) = bitand(obj.value(1),obj.mask);
            
        end
        
        function obj = leftShift(obj,places)
            
            if(places<0)
                error('don''t do that')
            end
            
            nWordShift = floor(places/32);

            for idx = 1:obj.words
                
                if(idx+nWordShift <= obj.words)
                    obj.value(idx) = obj.value(idx+nWordShift);
                else
                    obj.value(idx)=0;
                end
                
            end
            
            places = places-nWordShift*32;
            myMask = uint32(0);
            
            for idx = 1:places
                myMask = myMask+bitshift(uint32(1),32-idx);
            end
            
            for idx = 1:obj.words-1
               f=bitshift(bitand(obj.value(idx+1),myMask),places-32);
               obj.value(idx) = bitshift(obj.value(idx),places)+f;
            end
            
            obj.value(obj.words)=bitshift(obj.value(obj.words),places);
            obj.value(1) = bitand(obj.value(1),obj.mask);
        end
        
       
        function obj = rightShift(obj,places)
            
            if(places<0)
                error('don''t do that')
            end
            
            nWordShift = floor(places/32);

            for idx = obj.words:-1:1
                
                if(idx-nWordShift >= 1)
                    obj.value(idx) = obj.value(idx-nWordShift);
                else
                    obj.value(idx)=0;
                end
                
            end
            
            places = places-nWordShift*32;
            myMask = uint32(0);
            
            for idx = 1:places
                myMask = myMask+bitshift(uint32(1),idx-1);
            end
            
            for idx = obj.words:-1:2                
               f=bitshift(bitand(obj.value(idx-1),myMask),32-places);
               obj.value(idx) = bitshift(obj.value(idx),-places)+f;
            end
            obj.value(1)=bitshift(obj.value(1),-places);
            obj.value(1) = bitand(obj.value(1),obj.mask);%not necessary
        end
        
        function obj = shift(obj,places)
           if(places>0)
               obj.leftShift(places);
           else
               obj.rightShift(-places);
           end
        end
        
        function obj = not(obj)
            for idx = 1:obj.words
               obj.value(idx) = bitcmp(obj.value(idx)); 
            end
            
            obj.value(1) = bitand(obj.value(1),obj.mask);%necessary
        end
        
        function obj3 = and(obj1,obj2)
            
            if(obj1.bits > obj2.bits)
                obj2 = uintarb(obj1.bits,obj2.value);
            elseif(obj1.bits<obj2.bits)
                obj1 = uintarb(obj2.bits,obj1.value);
            end
            
            newValue = zeros(1,obj1.words);
            for idx = 1:obj1.words
               newValue(idx) = bitand(obj1.value(idx),obj2.value(idx)); 
            end
            
            newValue(1) = bitand(newValue(1),obj1.mask);%not necessary
            obj3 = uintarb(obj1.bits,newValue);
            
            
        end
        
        function obj3 = or(obj1,obj2)
            
            if(obj1.bits > obj2.bits)
                obj2 = uintarb(obj1.bits,obj2.value);
            elseif(obj1.bits<obj2.bits)
                obj1 = uintarb(obj2.bits,obj1.value);
            end
            
            newValue = zeros(1,obj1.words);
            for idx = 1:obj1.words
               newValue(idx) = bitor(obj1.value(idx),obj2.value(idx)); 
            end
            
            newValue(1) = bitand(newValue(1),obj1.mask);
            obj3 = uintarb(obj1.bits,newValue);
            
        end
        
        
        function [difference,underflow] = minus(obj1,obj2)
            
            if(obj1.bits > obj2.bits)
                obj2 = uintarb(obj1.bits,obj2.value);
            elseif(obj1.bits<obj2.bits)
                obj1 = uintarb(obj2.bits,obj1.value);
            end
            
        
            difference = obj1.value;
            
            for idx = obj2.words:-1:1
                
                if(difference(idx) >= obj2.value(idx))
                    difference(idx) = difference(idx)- obj2.value(idx);
                else
                    dummy = difference(idx);
                    
                    difference(idx) =  (bitcmp(uint32(0))-obj2.value(idx));
                    difference(idx) = difference(idx)+dummy+1;
                    
                    cidx = idx-1;
                    while(cidx>0 && difference(cidx)==0)
                        difference(cidx) =  bitcmp(uint32(0));
                        cidx = cidx-1;
                    end
                    if(cidx ~= 0)
                        difference(cidx)=difference(cidx)-1;
                    end
                end
            end
            
            %will mask top bits automatically. 
            difference = uintarb(obj1.bits,difference);
            underflow = obj2>obj1;
            
        end
        
        
        
        
        
        
        function [obj3,carryOut] = plus(obj1,obj2)
            
            if(obj1.bits > obj2.bits)
                obj2 = uintarb(obj1.bits,obj2.value);
            elseif(obj1.bits<obj2.bits)
                obj1 = uintarb(obj2.bits,obj1.value);
            end
            
            carryOut= uint32(0);
            value3 = zeros(1,obj1.words);
            
            for idx = obj1.words:-1:2
                [value3(idx),carryOut] = uintarb.addword(obj1.value(idx),obj2.value(idx),carryOut);
            end
            
            msbMask = bitshift(uint32(1),obj1.topWordBits-1);  
            lsbsMask = msbMask-1;
            w1_lsbs = bitand(lsbsMask,obj1.value(1));
            w2_lsbs = bitand(lsbsMask,obj2.value(1));
            value3(1) = w1_lsbs+w2_lsbs+carryOut;
            lsCarry = bitshift(bitand(msbMask,value3(1)),1-obj1.topWordBits);
            value3(1) = bitand(value3(1),lsbsMask);
            w1MSB = bitshift(bitand(msbMask,obj1.value(1)),1-obj1.topWordBits);
            w2MSB = bitshift(bitand(msbMask,obj2.value(1)),1-obj1.topWordBits);
            msbSum = lsCarry+w1MSB+w2MSB;
            carryOut = uint32(0);
            if(msbSum == 1)
                value3(1) =value3(1)+msbMask;  
            elseif(msbSum == 2)
                carryOut = uint32(1);
            elseif(msbSum == 3)
                value3(1) =value3(1)+msbMask;
                carryOut = uint32(1);
            end
            
            obj3 = uintarb(obj1.bits,value3);
        end
        
        function bool = ne(obj1,obj2)
            if(obj1.bits > obj2.bits)
                obj2 = uintarb(obj1.bits,obj2.value);
            elseif(obj1.bits<obj2.bits)
                obj1 = uintarb(obj2.bits,obj1.value);
            end
            
            i = obj1.words;
            while(i>0 && obj1.value(i)==obj2.value(i))   
                i = i-1;
            end
            
            bool = i>0;
            
        end
        
        function bool = gt(obj1,obj2)
            
            if(obj1.bits > obj2.bits)
                obj2 = uintarb(obj1.bits,obj2.value);
            elseif(obj1.bits<obj2.bits)
                obj1 = uintarb(obj2.bits,obj1.value);
            end
            
            idx = 1;
            while(idx <= obj1.words && obj1.value(idx) == obj2.value(idx))
               idx = idx+1; 
            end
            bool = ~(idx > obj1.words || obj1.value(idx) <= obj2.value(idx));
            
        end
        
        function bool = le(obj1,obj2)
            bool = ~gt(obj1,obj2);
        end
        
        function bool = lt(obj1,obj2)
           
            %le(obj1,obj2)&neq(obj1,obj2)
            if(obj1.bits > obj2.bits)
                obj2 = uintarb(obj1.bits,obj2.value);
            elseif(obj1.bits<obj2.bits)
                obj1 = uintarb(obj2.bits,obj1.value);
            end
            
            idx = 1;
            while(idx <= obj1.words  && obj1.value(idx) == obj2.value(idx))
               idx = idx+1; 
            end
            
            bool = ~(idx > obj1.words || obj1.value(idx) >= obj2.value(idx));
            
        end
        
        function bool = ge(obj1,obj2)
            bool = ~lt(obj1,obj2); 
        end
        
        function bool = eq(obj1,obj2)
           
            bool = ~ne(obj1,obj2);
            
        end
        
        function bool = bitget(obj,bidx)
            if(bidx<0 || bidx >= obj.bits)
                error('invalid bit index');
            end
            if(bidx < obj.topWordBits)
               
                myMask = bitshift(uint32(1),obj.topWordBits-1-bidx);
                bool = bitshift(bitand(obj.value(1),myMask), bidx+1-obj.topWordBits);
                
            else
                
                bidx = bidx-obj.topWordBits;
                widx = floor(bidx/32)+2;
                bidx = mod(bidx,32);
                myMask = bitshift(uint32(1),31-bidx);
                bool = bitshift(bitand(obj.value(widx),myMask), bidx-31);
                
            end
            
        end
        
        function bool = getbitatpow(obj,powidx)
           
            position = (obj.bits-1)-powidx;
            bool = bitget(obj,position);
            
        end
        
        function new = cast(bits,old)
            
            newWords = ceil(bits/32);
            
            if(bits < old.bits)
                error('no downcasting, yet'); 
            elseif(length(old.value)==newWords)
                newValue = old.value; 
            else
                newValue = uint32(zeros(1,newWords));
                newValue(((newWords-length(old.value))+1):end) = uint32(old.value);
            end
            
            new = uintarb(bits,newValue);
            
        end
        
        function new = bitsr(old,bidx,bool)
           
            if(bidx<0 || bidx >= old.bits)
                error('index out of range');
            end
            
            myMask = uintarb(old.bits,[uint32(zeros(1,floor(old.bits/32))),uint32(1)]);
            myMask = leftShift(myMask,old.bits-1-bidx);  
     
            if(bool==0)
               myMask = not(myMask);
               new = and(old,myMask);
            elseif(bool==1)
               new = or(old,myMask);
            else
                error('last input must be boolean (0 or 1)');
            end
            
        end
        
        
        function product = times(obj1,obj2)
        
            newBits = 2*max([obj1.bits,obj2.bits]);
            newWords = ceil(newBits/32);         
            product = uintarb(newBits,uint32(zeros(1,newWords)));
            
            if(newWords >= 2)
                for o1idx = (obj1.words):-1:1
                    for o2idx = (obj2.words):-1:1
                        %can do better but we're being lazy.        
                        pprod = uint64(obj1.value(o1idx))*uint64(obj2.value(o2idx));
                        wr = uint32(mod(pprod,bitshift(uint64(1),32)));
                        wl = uint32(bitshift(pprod,-32));
                        wordsShifted = (obj2.words-o2idx)+(obj1.words-o1idx);
                        dummy = uintarb(newBits,[zeros(1,newWords-2),wl,wr]);
                        product=product+leftShift(dummy,32*wordsShifted);
                    end
                end
            else
                product = uintarb(newBits,uint32(obj1.value(1)*obj2.value(1)));
            end
            
        end
        
        %Algorithm from Harris and Harris
        %Digital Design and Computer Architecture 2nd Ed. 
        function [quotient,remainder] = rdivide(a,b)
           
           if(a.bits > b.bits)
                b = uintarb(a.bits,b.value);
           elseif(a.bits<b.bits)
                a = uintarb(b.bits,a.value);
           end
           
           quotient = uintarb(a.bits,0);
           rTick= uintarb(a.bits, uint32(zeros(1,ceil(a.bits/32))));
           
           for bidx = 0:1:(a.bits-1)
               remainder = bitsr(leftShift(rTick,1),rTick.bits-1,bitget(a,bidx));
               if(lt(remainder,b))
                   quotient = bitsr(quotient,bidx,0);
                   rTick = remainder;
               else
                   quotient = bitsr(quotient,bidx,1);
                   rTick = remainder-b;
               end
           end
           
           remainder = rTick;
           
        end
        
    end
end

