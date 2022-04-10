clear;
close all;

InputDir = '.\2022data\';
%OutputDir = '.\2022data\';
files = dir([InputDir '*.mat']); %load all .mat files in the folder

%%
h = waitbar(0,'Please wait...');
filesNumber = length(files);

for i = 1 : filesNumber

    close all;

    %load([InputDir files(i).name]);
    fprintf('file(%d/%d): %s is loaded.\n',i,filesNumber,files(i).name(1:end-4));
    
       %% channel 12:NPress 13:Therm 14:Thor 15:Abdo 16:SpO2
    % 分析訊號 注意channels到底對不對
    data = load(fullfile(files(i).folder,files(i).name)); %load .mat files in the folder
    fs = 200; %睡眠中心 sample rate
    %fs = 512;  %社科院 sample rate
    data = data.data;
    
    % c3m2、c4m1、f3m2、f4m1、o1m2、o2m1、e1m2、e2m1、emgr
    exg = data(1:9, :);
    epoch = floor((width(exg) / fs) / 30);
    
    % stft 一秒一次不重疊
    window = fs * 1;
    overlap = 0;
    nfft = 2^nextpow2(window);
    for j = 1:height(exg)
        [s(j,:,:), f(j,:), t(j,:)] = spectrogram(exg(j,:), window, overlap, nfft, fs);
    end
    % s為能量強度
    s = abs(s);
    
    % 計算每個能量帶
    delta = []; % 0~4
    theta = []; % 4~7
    lalpha = []; % 8~10
    halpha = []; % 10~13
    lbeta = []; % 13~20
    hbeta = []; % 20~28
    gamma = []; % 28~50
    for j = 1:height(exg)
        for k = 1:width(t)
            delta(j, k) = sum(s(j, 1:6, k));
            theta(j, k) = sum(s(j, 7:10, k));
            lalpha(j, k) = sum(s(j, 11:14, k));
            halpha(j, k) = sum(s(j, 15:18, k));
            lbeta(j, k) = sum(s(j, 18:27, k));
            hbeta(j, k) = sum(s(j, 27:37, k));
            gamma(j, k) = sum(s(j, 37:65, k));
        end
    end
    
    waitbar(i/filesNumber,h,strcat('Please wait...',num2str(round(i/filesNumber*100)),'%'))    
end
close(h);