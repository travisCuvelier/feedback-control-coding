function Mp =  refGF2(M)

    [nr,nc] =size(M);

        if(nr == 1 )
            Mp = M;
        else

            swrow = 0;

            for ridx = 1:nr

                if(M(ridx,1) == 1)
                    swrow = ridx;
                    break
                end

            end

            if(swrow == 0 )
                Mp = M;

                if( nc ~= 1)
                    Mp(1:end,2:end) = refGF2(M(1:end,2:end));
                end

            else

                M = mswap(M,1,swrow);

                for ridx = 2:nr

                    if(M(ridx,1) == 1)

                        M(ridx,:) = xor(M(ridx,:),M(1,:));

                    end

                end

                Mp =M;

                if(nc~=1)
                    Mp(2:end,2:end) = refGF2(M(2:end,2:end));
                end
            end

        end

end

