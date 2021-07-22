function symbol = quantizeAndThread(r,varargin)
    
    if(isempty(varargin))
        delta=1;
    else
        delta =varargin{1};
    end
    
    symbol = myRound(r./delta);
    symbol = (symbol<=0).*(-2.0*symbol+1)+(symbol>0).*(2.0*symbol);
    
end

function rd = myRound(r)

rd=((r<0).*(mod(2*r,1)==0)).*ceil(r)+(~((r<0).*(mod(2*r,1)==0))).*round(r);

end

