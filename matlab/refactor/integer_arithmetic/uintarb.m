%uintarb is a matlab value (as opposed to handle) class that is used 
%to implement arbitrary precision unsigned integer arithmetic. 
%There is currently support for scalar operations on uintarbs, with 
%an eye to impelement vectorized operations in the future. 

classdef uintarb 
    
    properties
        
        words %the number of 32 bit words used to store the 
              %arbitrary precision integer. Equal to ceil(bits/32). 
              
        bits  %the precision of the unsigned integer, in bits. the value of
              %uintarb is an integer ranging from 0 to 2^(bits)-1
              %inclusive.
        
        value %the unsigned integers value, stored in 32 bit words.
              %value(1) is the most significant word, and value(words) the
              %least. The numerical value of the uintarb is 
              %value(1)*2^(words-1)+value(2)*2^(words-2)+...+value(words)
              
        topWordBits %If bits is not an integer mutliple of 32, then the 
                    %most significant word, value(1), will be an unsigned
                    %integer ranging from 0 to 2^(topWordBits)-1 inclusive.
        
        mask  %mask is a uint32 who's value is equal to 2^(topWordBits)-1.
              %this is a convenient thing to store. 
        
    end
    
    methods(Static)
        
       
        
        %if varargin is empty
        %given two uint32 words w1 and w2 add them together to obtain the 
        %32 bit least significant bits of the sum (w3) and a 
        %32 bit carry out that is either uint32(0) or uint32(1). 
        
        %if not empty, varargin can contain a "carry in" which is must be 1 
        %or 0 of a standard matlab type. The function computes
        %w1+w2+varargin{1} and produces  the 32 bit least significant bits 
        %of the sum (w3) and a 32 bit carry out that is either uint32(0) 
        %or uint32(1). 
        
        %N.B. it is easy to see that if w1 and w2 are unsigned 32 bit
        %numbers and "carry" is a 32 bit number such that "carry" = 0 or
        %"carry" = 1, then w1+w2+carry < 2^(33)-1, e.g. the result always
        %fits in 33 bits.
        
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
        
        %this function computes the highest possible integer as a uintarb.
        %It is comparable to "intmax", although it computes the value every
        %time it is called. It is thus ineffecient- for speed, consider
        %only calling once per script and saving returned value uintarb.
        function mx = maximumValue(precision)
            words = ceil(precision/32);            
            mask = uint32(0);
            %can make this faster and more efficient.
            for idx = 1:(words*32-precision)
                mask = mask+bitshift(uint32(1),32-idx);                
            end
            mask = bitcmp(mask,'uint32');
            valueWords = [mask];
            for idx = 2:words
                valueWords = [valueWords,intmax('uint32')];
            end
            mx = uintarb(precision,valueWords,false);
        end
        
        %A quicksort implementation. Sorts in descending order. Same output
        %as matlab builtin sort functions
        function [sorted,indices] = descendingQuicksort(vector)
    
            [sorted,indices] = uintarb.dive(vector,1:numel(vector));

        end
        
        
    end
    
    methods(Static=true,Access=private)
        %helper function for the quicksort implementation.
        function [sorted,sortedIndices] = dive(vector,indices)
            
            n = numel(vector);
            if(n>=2)
                
                nLeft = floor(numel(vector)/2);
                nRight = n-nLeft;
                [sortedLeft,indicesLeft] = uintarb.dive(vector(1:nLeft),indices(1:nLeft));
                [sortedRight,indicesRight] = uintarb.dive(vector((nLeft+1):end),indices((nLeft+1):end));
                pointerLeft = 1;
                pointerRight = 1;
                for idx = 1:n
                    if(pointerLeft<=nLeft && pointerRight <= nRight )
                        if(sortedLeft(pointerLeft)>= sortedRight(pointerRight))
                            sorted(idx) = sortedLeft(pointerLeft);
                            sortedIndices(idx) = indicesLeft(pointerLeft);
                            pointerLeft=pointerLeft+1;
                        else
                            sorted(idx) = sortedRight(pointerRight);
                            sortedIndices(idx) = indicesRight(pointerRight);
                            pointerRight = pointerRight+1;
                        end
                    elseif(pointerLeft>nLeft)
                        sorted(idx) = sortedRight(pointerRight);
                        sortedIndices(idx) = indicesRight(pointerRight);
                        pointerRight = pointerRight+1;
                    else
                        sorted(idx) = sortedLeft(pointerLeft);
                        sortedIndices(idx) = indicesLeft(pointerLeft);
                        pointerLeft = pointerLeft+1;
                    end
                end
                
            else
                
                if(n==0)
                    sorted = [];
                    sortedIndices = [];
                else
                    sorted = vector;
                    sortedIndices = indices;
                end
                
            end
            
            
        end
    end
    
    methods
        
        %Constructor
        %Inputs: 
        %bits = the precision to store the value. A uintarb is a positive
        %integer on the range 0 to 2^bits-1 inclusive. 
        %bits is assigned to the property bits and is used to set the 
        %properties "words", "topWordBits", and "mask". See the properties
        %section for descriptions before proceeding. 
        
        %valueWords = the value to be stored, passed as an array of 32-bit
        %integers. 
        
        %varargin{1} may is a boolean, assumed to be false. If true, it
        %will supress warnings. 
        
        %If length(valueWords) < words, the constructor preprends 
        %words-length(valueWords) elements equal to uint32(0) to
        %"valueWords" and sends a warning if warnings are not suppressed.
        %This is equivalent to assuming that the most significant 
        %words are equal to uint32(0). This can
        %be thought of as an increasing cast
        
        %If length(valueWords) > words, the first (most significant)   
        %length(valueWords)-words elements of valueWords will be ignored,
        %and valueWords will be reassigned the the least significant 
        %words= ceil(bits/32) elements of valueWords. A warning will be 
        %issued if not suppressed. The program then continues as if 
        %length(valueWords) = words. This is a decreasing cast.
        
        %if length(valueWords) = words, in most cases valueWords(1) should 
        %be a uint32 on the range 0 to 2^topWordBits-1 inclusive 
        %(where "topWordBits" is the property). The constructor will
        %truncate the most significant 32-topWordBits bits from value(1)
        %using mask. This is a decreasing cast. 
        %If after truncation, value(1) ~= valueWords(1),  a warning will be
        %issued, if not suppressed. This is a decreasing cast.
        
        %Note that up to two such "decreasing cast" warnings may be issued.
        %Consider call a = uintarb(7,[uint32(3542),uint32(255)]).
        %A seven bit integer is stored in one 32 bit word, so the most
        %significant word of [uint32(3542),uint32(255)] will be truncated, 
        %resulting in a warning. 
        %The funcation call proceeds as if we've called a= uintarb(7,[255])
        %modulo the warning. 
        
        %While 255 can be stored in 8 bits, it cannot be stored in
        %7 so a warning will be issued if not suppressed
        %, and the most significant bit truncated. The program proceeds as
        %if we've called a= uintarb(7,[127]) (since 127 =
        %bitand(uint32(255),mask)). 
        
        %In summary
        %a = uintarb(7,[uint32(3542),uint32(127)]) %one (word level) 
                                                    %overflow warning
        %b = uintarb(7,[uint32(255)]) %one (bit level) overflow warning
        %c = uintarb(7,[uint32(3542),uint32(255)]) %both overflow warnings
        %d = uintarb(7,[uint32(127)]) %no warnings
        %But we have (cf. eq below)
        %eq(a,b) //will be "true"
        %eq(a,c) //will be "true"
        %eq(a,d) //will be "true"
        %eq(b,c) //will be "true"
        %eq(b,d) //will be "true"
        %eq(c,d) //will be "true"
        
        function obj = uintarb(bits,valueWords,varargin)
            
            if(isempty(varargin)||~islogical(varargin{1}))
                suppressWarnings = false;
            else
                suppressWarnings = varargin{1};
            end
                
            obj.words = ceil(bits/32);
            obj.bits = bits;
            
            if(length(valueWords)<obj.words)
                %if(~suppressWarnings)
                    %warning('I''m filling in zeros for most significant words');
                %end
                obj.value = uint32(zeros(1,obj.words));
                obj.value(((obj.words-length(valueWords))+1):end) = uint32(valueWords);
            else
                
                if(length(valueWords) > obj.words)
                    if(~suppressWarnings)
                        warning('Overflow (word level)');
                    end
                    wordDiff = length(valueWords)-obj.words;
                    valueWords = valueWords(wordDiff+1:end); %will be masked by uintarbcontstructor
                end
                    
                obj.value = uint32(valueWords);

            end
            
            mask = uint32(0);
            %can make this faster and more efficient.
            for idx = 1:(obj.words*32-bits)
                mask = mask+bitshift(uint32(1),32-idx);                
            end
            obj.mask = bitcmp(mask,'uint32');
            obj.topWordBits = bits- (obj.words-1)*32;
            obj.value(1) = bitand(obj.value(1),obj.mask);
            %This warning is not quite right, will have to fix. 
            if((~suppressWarnings) && (length(valueWords)==obj.words) &&(obj.value(1)~= valueWords(1)))
                warning('Overflow (bit level)');
            end
            
        end
        

        %leftShift is and in-place left-shift operation. For "a" an uintarb
        %leftShift(a,places) is notionally equivalent to "a<<places" in 
        %C/C++/Java/etc.
        
        %Inputs:
        %obj = a uintarb
        %places = the number of bit indices to left shift. Must be
        %nonnegative
        
        %Output
        %obj = a unintarb object, with the same number of bits as the 
        %input. The numerical value of the output has a binary expansion
        %given by the obj.bits least significant bits of 
        %2^places*(the numerical value of obj). (Shift in zeros, ignore
        %overflow).
        
        function obj = leftShift(obj,places)
            
            if(places<0)
                error('places must be nonnegative')
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
        
        %rightShift is and in-place right-shift operation For "a" an
        %uintarb rightshift(a,places) is notionally equivalent to 
        %"a>>places" in C/C++/Java/etc.
        
        %Inputs:
        %obj = a uintarb
        %places = the number of bit indices to right shift. Must be
        %nonnegative. 
        
        %Output
        %obj = a unintarb object, with the same number of bits as the 
        %input and a numerical value equal to
        %floor((the numerical value of obj)/2^places).
       
        function obj = rightShift(obj,places)
            
            if(places<0)
                error('places must be nonnegative')
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
        
        %shift is a wrapper for leftShift and rightShift. 
        %Inputs:
        %obj = a uintarb
        %places = an integer
        %Output:
        %if places is nonnegative, returns leftShift(obj,places)
        %if places is negative, returns rightShift(obj,-places)
        
        function obj = shift(obj,places)
           if(places>=0)
               obj.leftShift(places);
           else
               obj.rightShift(-places);
           end
        end
        
        %not is in-place bitwise not.
        %Inputs:
        %obj = a uintarb
        %Output:
        %obj = a uintarb object with the same number of bits as the input. 
        %Let "bits" be the number of bits in the input.
        %The output has a numerical value equal to 2^(obj.bits)-1-(the
        %numerical value of the input).
        
        function obj = not(obj)
            for idx = 1:obj.words
               obj.value(idx) = bitcmp(obj.value(idx)); 
            end
            
            obj.value(1) = bitand(obj.value(1),obj.mask);%necessary
        end
        
        %and is bitwise and.
        %Inputs:  obj1, obj2 = uintarb operands
        %Outputs: obj3, a uintarb with obj3.bits = max(obj1.bits,obj2.bits)
        %
        %The function first casts argmin(obj1.bits,obj2.bits) to the size
        %given by max(obj1.bits,obj2.bits). This just adds leading zeros.
        %obj3.value is the bitwise and computed between the casted words in
        %obj1.value and obj2.value. The speed of this operation
        %should be improved by noting that any increasing cast simply
        %preprends leading zeros, which guarantees leading zeros in the
        %result.
        
        function obj3 = and(obj1,obj2)
   
            
            if(obj1.bits > obj2.bits)
                obj2 = uintarb(obj1.bits,obj2.value,true);
            elseif(obj1.bits<obj2.bits)
                obj1 = uintarb(obj2.bits,obj1.value,true);
            end
            
            newValue = zeros(1,obj1.words);
            for idx = 1:obj1.words
               newValue(idx) = bitand(obj1.value(idx),obj2.value(idx)); 
            end
            
            newValue(1) = bitand(newValue(1),obj1.mask);%not necessary
            obj3 = uintarb(obj1.bits,newValue);
            
        end
        
        
        %or is bitwise or.
        %Inputs: obj1, obj2 = uintarb operands
        %Outputs: obj3= a uintarb with obj3.bits = max(obj1.bits,obj2.bits)
        %
        %The function first casts argmin(obj1.bits,obj2.bits) to the size
        %given by max(obj1.bits,obj2.bits). This just adds leading zeros.
        %obj3.value is the bitwise OR computed between the casted words in
        %obj1.value and obj2.value. 
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
        
        %minus is unsigned subtraction
        %Inputs: obj1, obj2 =  uintarb operands.
        %Outputs: 
        %difference= a uintarb with 
        %difference.bits = max(obj1.bits,obj2.bits)
        %difference.value is such that the numerical value of difference is
        %given by:
        %(numerical value of obj1)-(numerical value of obj2) when 
        %(numerical value of obj1)>=(numerical value of obj2)
        %or
        %(numerical value of obj1)-(numerical value of obj2)+...
        %... 2^max(obj1.bits,obj2.bits),
        %when (numerical value of obj1)<(numerical value of obj2)
        %
        %underflow = a logical variable that is true if obj1 has a
        %numerical value that is less than obj2. 
        
        function [difference,underflow] = minus(obj1,obj2)
            
            if(obj1.bits > obj2.bits)
                obj2 = uintarb(obj1.bits,obj2.value,true);
            elseif(obj1.bits<obj2.bits)
                obj1 = uintarb(obj2.bits,obj1.value,true);
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
        
        
        %plus is unsigned addition
        %Inputs: obj1, obj2 =  uintarb operands.
        %Outputs: 
        %obj3 = a uintarb such that 
        %obj3.bits = max(obj1.bits,obj2.bits)
        %obj3.value = the least significant bits of the sum of the
        %numerical values of obj1 and obj2. 
        %carryOut = a one bit carry, which is given by uint32(1) if the sum
        %overflows and uint32(0) otherwise. 
        
        %We have:
        %(numerical value of obj3) + ... 
        %...(numerical value of carryOut)*2^obj3.bits =...
        %       ...(numerical value of obj1)+(numerical value of obj2).
        function [obj3,carryOut] = plus(obj1,obj2)
            
            if(obj1.bits > obj2.bits)
                obj2 = uintarb(obj1.bits,obj2.value,true);
            elseif(obj1.bits<obj2.bits)
                obj1 = uintarb(obj2.bits,obj1.value,true);
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
        
        %ne is not equal
        %Inputs: obj1, obj2 = two uintarbs
        %Outputs:
        %bool = a logical, true if and onld if the numerical values of
        %obj1 and obj2 are not equal.
        %
        %obj1.bits need not equal obj2.bits, an increasing cast will be
        %made. The speed of this function could be improved by avoiding a
        %cast and checking for inequality from least significant to most
        %significant bits. 
        
        function bool = ne(obj1,obj2)
            if(obj1.bits > obj2.bits)
                obj2 = uintarb(obj1.bits,obj2.value,true);
            elseif(obj1.bits<obj2.bits)
                obj1 = uintarb(obj2.bits,obj1.value,true);
            end
            
            i = obj1.words;
            while(i>0 && obj1.value(i)==obj2.value(i))   
                i = i-1;
            end
            
            bool = i>0;
            
        end
        
        %gt is greater than, 
        %Inputs: obj1, obj2 = two uintarbs
        %Outputs:
        %bool = true if and only if the numerical value of obj1 exceeds 
        %the numerical value of obj2. 
        %obj1.bits need not equal obj2.bits, an increasing cast will be
        %made. The speed of this function could be improved by avoiding a
        %cast, at the expense of complicated code.
        
        function bool = gt(obj1,obj2)
            
            if(obj1.bits > obj2.bits)
                obj2 = uintarb(obj1.bits,obj2.value,true);
            elseif(obj1.bits<obj2.bits)
                obj1 = uintarb(obj2.bits,obj1.value,true);
            end
            
            idx = 1;
            while(idx <= obj1.words && obj1.value(idx) == obj2.value(idx))
               idx = idx+1; 
            end
            bool = ~(idx > obj1.words || obj1.value(idx) <= obj2.value(idx));
            
        end
        
        %le is less than or equal to
        %Inputs: obj1, obj2 = two uintarbs
        %Outputs:
        %bool = true if and only if the numerical value of obj1 does not
        %exceed the numerical value of obj2. Calls gt. 
        
        function bool = le(obj1,obj2)
            bool = ~gt(obj1,obj2);
        end
        
        
        
        function bool = lt(obj1,obj2)
           
            %le(obj1,obj2)&neq(obj1,obj2)
            if(obj1.bits > obj2.bits)
                obj2 = uintarb(obj1.bits,obj2.value,true);
            elseif(obj1.bits<obj2.bits)
                obj1 = uintarb(obj2.bits,obj1.value,true);
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
        
        function new = upCast(old,bits)
            
            newWords = ceil(bits/32);
            
            if(bits < old.bits)
                error('this function is only for upcasting'); 
            elseif(length(old.value)==newWords)
                newValue = old.value; %will automally fill zeros
            else
                newValue = uint32(zeros(1,newWords));
                newValue(((newWords-length(old.value))+1):end) = uint32(old.value);
            end
            
            new = uintarb(bits,newValue);
            
        end
        
        function [new,overflow] = downCast(old,bits)
            
            newWords = ceil(bits/32);
            overflow = false; 
            
            if(bits > old.bits)
                error('this function is only for downcasting')               
            else
                
                wordDiff = old.words-newWords;
                newValue = old.value(wordDiff+1:end); %will be masked by uintarbcontstructor
                newTopWordBits = bits-(newWords-1)*32;

                if(sum(old.value==uint32(0)) < wordDiff || (newTopWordBits~=32 && newValue(1)> uint32(2^newTopWordBits-1)) )
                    overflow = true;
                end
                new = uintarb(bits,newValue,true);%will mask top word automatically            
            end
            
            
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
        
        function str = getMSBs(obj,howMany)
            str = [];
            for idx = (obj.bits-1):-1:(obj.bits-howMany)
                str = [str,obj.getbitatpow(idx)];%slow but idk
            end
        end
        
    end
end

