%finds the number of points on the integer lattice that intersect the d
%dimensional l1 sphere of radius n

function number  = latticeCount(d,n)
    
    if(d<=0 || n<0 || mod(d,1)||mod(n,1))
        error('d must be a positive integer, n must be a nonnegative integer');
    end
    
    if(n ~=0)
        number = 0;
        for i = max(0,d-n):(d-1)
            number = number + nchoosek(d,i)*nchoosek(n-1,d-i-1)*2^(d-i);
            nchoosek(d,i)*nchoosek(n-1,d-i-1)*2^(d-i)
        end
    else 
        number = 1;
    end


end