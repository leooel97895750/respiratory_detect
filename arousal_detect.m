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
    %s_max = max(s);
    %s = (s ./ s_max) .* 100;
    
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
    
    %% 標準答案
    aasm2020 = readtable('.\2022data\20191018_徐O文_2020aasm.csv');
    arousal2020 = zeros(1, epoch*30);
    for j = 1:height(aasm2020)
        if string(aasm2020(j, 1).Var1) == "ARO SPONT"
            arousal2020(1, round(aasm2020(j, 2).Var2) : round(aasm2020(j, 2).Var2 + aasm2020(j, 3).Var3)) = 1;
        end
    end
    
    figure();
    hold on; grid on;
    plot(halpha(1, :));
    arousal_bar = bar(arousal2020*5000, 'FaceColor', 'r', 'BarWidth', 1);
    set(arousal_bar, 'FaceAlpha', 0.2);
    
    %% adaptive threshold
    halpha_arousal = zeros(1, length(halpha)); % 0:無事件、1:Arousal、2:因檢查為階段轉換迴圈跳過的部分
    window = 15;
    threshold1 = mean(halpha(1:window)) + 3 * std(halpha(1:window));
    threshold2 = mean(halpha(1:window)) - 3 * std(halpha(1:window));
    for j = (window+1):length(halpha)
        if halpha_arousal(j) == 0
            % 若超出threshold則做arousal檢查
            if halpha(j) > threshold1 || halpha < threshold2
                % 往後檢查30秒
                arousal_second = zeros(1, 30);
                for k = 1:30
                    if halpha(j+k) > threshold1 || halpha < threshold2
                        arousal_second(1, k) = 1;
                    end
                end
                % 若大於20秒視為階段轉換
                if sum(arousal_second) > 20
                    halpha_arousal(j:j+30) = 2;
                % 若小於20秒且秒數集中於前段則視為Arousal
                else
                    
                end
                
            % 若在threshold內則更新threshold
            else
                threshold1 = mean(halpha(j:j+window)) + 3 * std(halpha(j:j+window));
                threshold2 = mean(halpha(j:j+window)) - 3 * std(halpha(j:j+window));
            end
        end
    end
    
    
    waitbar(i/filesNumber,h,strcat('Please wait...',num2str(round(i/filesNumber*100)),'%'))    
end
close(h);