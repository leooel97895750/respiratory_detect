clear;
close all;
InputDir = '.\workshop0606data\rawdata\';
files = dir([InputDir '*.mat']); %load all .mat files in the folder
h = waitbar(0,'Please wait...');
filesNumber = length(files);
for i = 1 : filesNumber
    close all;
    fprintf('file(%d/%d): %s is loaded.\n',i,filesNumber,files(i).name(1:end-4));
    
    lpFilt = designfilt('lowpassfir', 'FilterOrder', 50, 'CutoffFrequency', 4, 'Samplerate', 25);
    %fvtool(lpFilt);
    
    data = load(fullfile(files(i).folder,files(i).name)); %load .mat files in the folder
    fs = 200; %睡眠中心 sample rate
    data = data.data;
    eeg = data(1, :);
    epoch = floor((length(eeg) / fs) / 30);
    npress = data(12, :);
    npress = npress(1:epoch*30*25);
    
    lp_npress = filter(lpFilt, npress);
    figure();
    hold on; grid on;
    plot(npress);
    plot(lp_npress);
    
    waitbar(i/filesNumber,h,strcat('Please wait...',num2str(round(i/filesNumber*100)),'%'))    
end
close(h);