clear all
%this code tests for vector sources
encoderModels = conditionalCountManager32([2,2]);
encoder = vectorArithmeticEncoder32(encoderModels);
decoderModels = conditionalCountManager32([2,2]);
decoder = vectorArithmeticDecoder32(decoderModels);

nSourceTuples = 90000;

for idx = 1:nSourceTuples

    rv = rand;
    if(rv <= .75)
        s(idx,1) = 0;
        
        if(rand>.5)
            s(idx,2)=1;
        else
            s(idx,2) = 2;
        end

    elseif(rv <=.875 )
        s(idx,1) = 1;
        s(idx,2) = 2;
    else
        s(idx,1) = 2; %draw second index (roughly) uniform
        
        rv2 = rand;
        if(rv2 <=.33)
            s(idx,2) = 0;
        elseif(rv2 <=.67)
            s(idx,2) = 1;
        else
            s(idx,2) = 2;
        end
    end

end
mcwl = 0;
for idx = 1:nSourceTuples
    bits = encoder.encodeTupleAndUpdateModel(squeeze(s(idx,:)));
    mcwl = mcwl+length(bits)/nSourceTuples;
    decoded(idx,:) = decoder.decodePacketAndUpdate(bits);
end
sum(sum(s~=decoded))

% for idx = 1:1
%     bits = encoder.encodeTupleAndUpdateModel(squeeze(s(idx,:)));
%     tuple = decoder.decodePacketAndUpdate(bits);
% end

%The code below tests for scalar sources
% encoderModels = conditionalCountManager32([2]);
% encoder = vectorArithmeticEncoder32(encoderModels);
% decoderModels = conditionalCountManager32([2]);
% decoder = vectorArithmeticDecoder32(decoderModels);
% s = [0 0 0 0 0 1 1 0 0 0 0 0 0 ];
% for idx = 1:numel(s)
%    bits = encoder.encodeTupleAndUpdateModel(s(idx));
%    decoded(idx) = decoder.decodePacketAndUpdate(bits);
% end