f = @(x,s) exp(-x.^2/(2*s))./sqrt(2*pi*s)
s1 = 2.000000;
s2 =2.0000001 ;
l = 1;
x = l:.001:50*max(s1,s2)*l;
%plot(x,f(x-1,s1),'linewidth',4)
%hold on
%plot(x,f(x+1,s2),'linewidth',4)
semilogy(x/sqrt((s1+s2)/2),f(x,s1)./f(x+1,s2),'linewidth',4)
hold on

