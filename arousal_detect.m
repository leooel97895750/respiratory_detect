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
    
    c3m2 = data(1, :);
    c4m1 = data(2, :);
    f3m2 = data(3, :);
    f4m1 = data(4, :);
    o1m2 = data(5, :);
    o2m1 = data(6, :);
    e1m2 = data(7, :);
    e2m1 = data(8, :);
    emgr = data(9, :);
    epoch = floor((length(c3m2) / fs) / 30);
    
    %[Amp(i,:,:),f(i,:),t1(i,:)] = spectrogram(epoch_EXGsignal_seg(:,i),window,overlap,nfft,fs);
    
    waitbar(i/filesNumber,h,strcat('Please wait...',num2str(round(i/filesNumber*100)),'%'))    
end
close(h);