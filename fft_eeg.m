clear;
close all;
InputDir = '.\2022data\';
files = dir([InputDir '*.mat']); %load all .mat files in the folder
h = waitbar(0,'Please wait...');
filesNumber = length(files);
for i = 1 : filesNumber
    close all;
    fprintf('file(%d/%d): %s is loaded.\n',i,filesNumber,files(i).name(1:end-4));

    %
    data = load(fullfile(files(i).folder,files(i).name)); %load .mat files in the folder
    fs = 200; %睡眠中心 sample rate 200 社科院 sample rate 512
    data = data.data;
    
    % c3m2、c4m1、f3m2、f4m1、o1m2、o2m1、e1m2、e2m1、emgr
    exg = data(1:9, :);
    epoch = floor((width(exg) / fs) / 30);

    c3m2 = exg(1, 500000:500200);
    c3m2_fft = fft(c3m2, 256);
    f = (0:length(c3m2_fft)-1)*fs/length(c3m2_fft);
    c3m2_fft = abs(c3m2_fft);
    power = c3m2_fft.^2/length(c3m2_fft);
    plot(f, power);


    waitbar(i/filesNumber,h,strcat('Please wait...',num2str(round(i/filesNumber*100)),'%'))    
end
close(h);