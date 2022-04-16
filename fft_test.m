clear;
fs = 100;
t = 0:1/fs:5-1/fs;
y = sin(2*pi*15*t) + sin(2*pi*30*t);
Y = fft(y, 512);
% f = (0:length(Y)-1)*fs/length(Y);
% Y = abs(Y);
% power = Y.^2/length(Y);
% plot(f, power);