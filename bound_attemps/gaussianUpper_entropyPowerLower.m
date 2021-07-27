A = 1.1;
W = 1;
fudge = 12/(2*pi*exp(1));
[Ptilde,Phat] = meshgrid(.1:1:10000,.1:1:10000);
factor2 = Ptilde.*Phat./(Ptilde-Phat);
TOP = inv(W)*(Phat./(Ptilde-Phat)).*(Ptilde+A^2*Ptilde-2*Phat)+1;
BOTTOM = fudge*A^2*inv(W)*(Phat.*(Ptilde-Phat)./Ptilde)+1;

TOP(Phat > Ptilde) = 1;
BOTTOM(Phat > Ptilde) = 1; 

%surf(Ptilde,Phat,log2(TOP./BOTTOM));

TOP2 = 1+inv(W)*factor2.*(1+A^2*((Ptilde-Phat)./Ptilde).^2);
BOTTOM2 = 1+A^2*fudge*factor2.*((Ptilde-Phat)./Ptilde).^2*inv(W);
TOP2(Phat >= Ptilde) = 1;
BOTTOM2(Phat >= Ptilde) = 1; 

surf(Ptilde,Phat,log2(TOP2./BOTTOM2));