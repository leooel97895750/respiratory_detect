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

    % 選擇channels 以一秒為window，重疊0.9秒，做fft(整晚訊號直接跑電腦會很盪)
    c = 1;
    [s, f, t] = spectrogram(exg(c, 1:100000), 200, 180, 256, 200);
    figure();
    surf(t, f, abs(s)./max(abs(s)), 'EdgeColor', 'None');
    colorbar;
    colormap jet;
    set(gca, 'Clim', [0, 1]);
    view([0, 90]);
    axis tight;
    ylim([0, 40]);
    ylabel('Frequency (Hz)');
    xlabel('Times (s)');


    waitbar(i/filesNumber,h,strcat('Please wait...',num2str(round(i/filesNumber*100)),'%'))    
end
close(h);