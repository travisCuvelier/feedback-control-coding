x = 1:.001:100;
y = x+(1+x).*log(1+x)-x.*log(x);
yu = x+log(x)+1.4;
yl = x+log(x)+1;

plot(x,y,'linewidth',4)
hold on
plot(x,yu,'linewidth',4)
plot(x,yl,'g','linewidth',4)
hold off
