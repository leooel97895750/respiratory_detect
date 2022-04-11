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
        [s(j,:,:), f, t] = spectrogram(exg(j,:), window, overlap, nfft, fs);
    end
    % s為能量強度
    s = abs(s);
    %s_max = max(s);
    %s = (s ./ s_max) .* 100;
    
    % 計算每個能量帶
    % delta 0.5~4、theta 4~8、alpha 8~13、lbeta 13~28、gamma 28~50
    band = [];
    for j = 1:height(exg)
        for k = 1:epoch*30
            band(1, j, k) = sum(s(j, 2:6, k))/5;
            band(2, j, k) = sum(s(j, 6:11, k))/6;
            band(3, j, k) = sum(s(j, 11:18, k))/8;
            band(4, j, k) = sum(s(j, 18:37, k))/20;
            band(5, j, k) = sum(s(j, 37:65, k))/29;
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
    %% adaptive threshold
    %halpha_arousal = zeros(1, length(halpha(1, :))); % 0:無事件、1:Arousal、2:因檢查為階段轉換迴圈跳過的部分
    
    
    % 畫出每個channel的圖
%     window = 15;
% 
%     for b = 1:height(band)
%         for c = 1:width(band)
%             tplotx = [];
%             t1ploty = [];
%             t2ploty = [];
%             for j = window+1:epoch*30
% 
%                 threshold1 = mean(band(b, c, j-window:j)) + 3 * std(band(b, c, j-window:j));
%                 threshold2 = mean(band(b, c, j-window:j)) - 3 * std(band(b, c, j-window:j));
%                 tplotx(end+1) = j;
%                 t1ploty(end+1) = threshold1;
%                 t2ploty(end+1) = threshold2;
% 
%             end
%             figure();
%             hold on; grid on;
%             plot(reshape(band(b, c, :), 1, []));
%             plot(tplotx, t1ploty);
%             plot(tplotx, t2ploty);
%             arousal_bar = bar(arousal2020*5000, 'FaceColor', 'r', 'BarWidth', 1);
%             set(arousal_bar, 'FaceAlpha', 0.2);
%             title(string(b) + " in " + string(c));
%         end
%     end
    
    %% 觀察Arousal在各種channels下的組成 (看不出一個所以然來)
    for c = 1:height(exg)
        arousal_fft(c, :, :) = reshape(s(c, :, find(arousal2020 == 1)), 129, []);
        arousal_fft(c, :, :) = 20*log10(arousal_fft(c, :, :));
        
        for j = 1:epoch*30
            exg_amp(c, j) = sum(abs(exg(c, (j-1)*fs+1:j*fs)));
        end
        arousal_amp(c, :) = exg_amp(c, find(arousal2020 == 1));
        
%         figure();
%         hold on; grid on;
%         for k = 1:length(arousal_fft)
%             plot(f(1:65), arousal_fft(1:65, k));
%         end
%         title(string(c));
    end
    % 畫圖 撒點觀察 x = band energy ; y = singal amplitude
    channels = ["c3m2","c4m1","f3m2","f4m1","o1m2","o2m1","e1m2","e2m1","emgr"];
    for j = 1:length(channels)
        figure(); hold on; grid on;
        scatter(band(1, j, find(arousal2020 == 1)), arousal_amp(j, :), 'DisplayName', 'delta', 'MarkerEdgeAlpha', 0.5);
        scatter(band(2, j, find(arousal2020 == 1)), arousal_amp(j, :), 'DisplayName', 'theta', 'MarkerEdgeAlpha', 0.5);
        scatter(band(3, j, find(arousal2020 == 1)), arousal_amp(j, :), 'DisplayName', 'alpha', 'MarkerEdgeAlpha', 0.5);
        scatter(band(4, j, find(arousal2020 == 1)), arousal_amp(j, :), 'DisplayName', 'beta', 'MarkerEdgeAlpha', 0.5);
        scatter(band(5, j, find(arousal2020 == 1)), arousal_amp(j, :), 'DisplayName', 'gamma', 'MarkerEdgeAlpha', 0.5);
        ylim([0  30000]);
        xlim([0 3000]);
        title(channels(j));
    end
    
    % 抓個案來看
    
    waitbar(i/filesNumber,h,strcat('Please wait...',num2str(round(i/filesNumber*100)),'%'))    
end
close(h);