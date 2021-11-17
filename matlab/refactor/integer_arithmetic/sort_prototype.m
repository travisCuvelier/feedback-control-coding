function [sorted,indices] = sort_prototype(vector)
    
    [sorted,indices] = dive(vector,1:numel(vector));

end

function [sorted,sortedIndices] = dive(vector,indices)

    n = numel(vector);
    if(n>=2)
        
        nLeft = floor(numel(vector)/2);
        nRight = n-nLeft;
        [sortedLeft,indicesLeft] = dive(vector(1:nLeft),indices(1:nLeft));
        [sortedRight,indicesRight] = dive(vector((nLeft+1):end),indices((nLeft+1):end));
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