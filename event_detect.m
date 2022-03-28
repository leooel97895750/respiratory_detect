clear
close all

InputDir = 'C:\Users\leooel97895750\Desktop\respiratory_detect\2022data\';
%OutputDir = 'C:\Users\leooel97895750\Desktop\respiratory_detect\2022data\';
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

    eeg = data(1, :);
    epoch = floor((length(eeg) / fs) / 30);

    npress = data(12, :);
    npress = npress(1:epoch*30*25);
    therm = data(13, :);
    therm = therm(1:epoch*30*25);
    thor = data(14, :);
    thor = thor(1:epoch*30*25);
    abdo = data(15, :);
    abdo = abdo(1:epoch*30*25);
    spo2 = data(16, :);
    spo2 = spo2(1:epoch*30);

    figure(1);
    subplot(5, 1, 1);
    plot((1:epoch*30*25), npress);
    subplot(5, 1, 2);
    plot((1:epoch*30*25), therm);
    subplot(5, 1, 3);
    plot((1:epoch*30*25), thor);
    subplot(5, 1, 4);
    plot((1:epoch*30*25), abdo);
    subplot(5, 1, 5);
    plot((1:epoch*30), spo2);

    %% emd分解
    % [imf,residual,info] = emd(npress,'MaxNumIMF', 4);
    % figure(2);
    % hht(imf, 25);
    % figure(3);
    % ax(1) = subplot(5, 1, 1);
    % plot(imf(:, 1));
    % ax(2) = subplot(5, 1, 2);
    % plot(imf(:, 2));
    % ax(3) = subplot(5, 1, 3);
    % plot(imf(:, 3));
    % ax(4) = subplot(5, 1, 4);
    % plot(imf(:, 4));
    % ax(5) = subplot(5, 1, 5);
    % plot(npress);
    % 
    % linkaxes(ax, 'x');

    %% find peaks

    % 設定npress的最小高度與最小間隔，抓取波峰與波谷
    % 波峰
    [upper_pks, upper_locs] = findpeaks(npress, 'MinPeakDistance', 25*3, 'MinPeakHeight', 0);
    % 波谷 反轉訊號計算
    [lower_pks, lower_locs] = findpeaks(npress*-1, 'MinPeakDistance', 25*3, 'MinPeakHeight', 0);

    figure(4);
    plot((1:epoch*30*25), npress, upper_locs, upper_pks, 'or', lower_locs, lower_pks*-1, 'og');

    %% curve fit 要安裝curve fitting toolbox
    upper_curve = fit(upper_locs.', upper_pks.', 'smoothingspline', 'SmoothingParam', 0.0001);
    lower_curve = fit(lower_locs.', (lower_pks*-1).', 'smoothingspline', 'SmoothingParam', 0.0001);
    figure(5);
    plot((1:epoch*30*25), npress); hold on;
    plot(upper_curve, 'r', upper_locs, upper_pks, 'ro');
    plot(lower_curve, 'g', lower_locs, lower_pks*-1, 'go');

    %% 計算震幅變化
    figure(6); hold on;
    uc = plot(upper_curve, 'r', upper_locs, upper_pks, 'w');
    lc = plot(lower_curve, 'g', lower_locs, lower_pks*-1, 'w');
    set(uc, 'linewidth', 2);
    set(lc, 'linewidth', 2);

    
    waitbar(i/filesNumber,h,strcat('Please wait...',num2str(round(i/filesNumber*100)),'%'))    
end
close(h);