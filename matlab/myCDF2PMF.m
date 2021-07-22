function pmf = myCDF2PMF(myCDF)

    for idx = 1:(length(myCDF)-1)
       pmf(idx) = double(myCDF(idx)-myCDF(idx+1));
    end
    
    pmf = pmf/double(myCDF(1));
    
end