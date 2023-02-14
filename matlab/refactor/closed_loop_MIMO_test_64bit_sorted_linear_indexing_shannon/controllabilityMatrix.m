function cMat = controllabilityMatrix(A,B)

    cMat = dive(A,B,1);

end

function cMat = dive(A,B,idx)

    n = size(A,1);
    
    if(idx < n)
        cMat = [B,A*dive(A,B,idx+1)];
    else
       cMat = B; 
    end
    
end