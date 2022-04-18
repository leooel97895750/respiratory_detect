clear;
close all;

% InputDir = '.\2022data\';
InputDir = '.\workshop0606data\rawdata\';
%OutputDir = '.\2022data\';
files = dir([InputDir '*.mat']); %load all .mat files in the folder

%%
h = waitbar(0,'Please wait...');
filesNumber = length(files);

for i = 1 : filesNumber

    close all;
    fprintf('file(%d/%d): %s is loaded.\n',i,filesNumber,files(i).name(1:end-4));
    
    %% channels
    % 分析訊號 注意channels到底對不對
    data = load(fullfile(files(i).folder,files(i).name)); %load .mat files in the folder
    fs = 200; %睡眠中心 sample rate 200 社科院 sample rate 512
    data = data.data;
    
    % c3m2、c4m1、f3m2、f4m1、o1m2、o2m1、e1m2、e2m1、emgr
    exg = data(1:9, :);
    epoch = floor((width(exg) / fs) / 30);

    %% 標準答案
    stage = readtable('.\workshop0606data\stage\stage.csv');
    stage = stage.Var1;
    aasm2020 = readtable('.\workshop0606data\ncku_golden_event.csv');
%     aasm2020 = readtable('.\2022data\20191018_徐O文_2020aasm.csv');
    arousal2020 = zeros(1, epoch*30);
    for j = 1:height(aasm2020)
        if string(aasm2020(j, 1).Var1) == "ARO SPONT"
            arousal2020(1, round(aasm2020(j, 2).Var2) : round(aasm2020(j, 2).Var2 + aasm2020(j, 3).Var3)) = 1;
        end
    end
    
    %% 分析
    % stft 一秒一次不重疊
    window = fs * 1;
    overlap = 0;
    nfft = 2^nextpow2(window);
    for j = 1:6
        [s(j,:,:), f, t] = spectrogram(exg(j, :), window, overlap, nfft, fs);
    end
    % s為能量強度
    s = abs(s);
    s = (s ./ max(reshape(s, [], 1))) .*100;
    
    % band
    % 計算每個能量帶
    % delta 0.5~4、theta 4~8、alpha 8~13、lbeta 13~28、gamma 28~50
    band = zeros(5, 6, epoch*30);
    for j = 1:6
        for k = 1:epoch*30
            band(1, j, k) = mean(s(j, 2:6, k));
            band(2, j, k) = mean(s(j, 6:11, k));
            band(3, j, k) = mean(s(j, 11:18, k));
            band(4, j, k) = mean(s(j, 18:37, k));
            band(5, j, k) = mean(s(j, 37:65, k));
        end
    end


    % exg_amplitude
    % 計算每2秒震幅大小 overlap 1秒
    exg_amplitude = zeros(9, epoch*30);
    for j = 1:height(exg)
        for k = 1:epoch*30
            segment = exg(j, (k-1)*fs+1:(k-1)*fs+fs*2);
            exg_amplitude(j,k) = max(segment) - min(segment);
        end
    end

    % exg_abnormal
    % 定義訊號異常矩陣 超過threshold視為abnormal
    threshold = 300; % for eeg
    exg_abnormal = zeros(9, epoch*30);
    for j = 1:height(exg_amplitude)
        for k = 1:epoch*30
            if exg_amplitude(j, k) >= threshold
                exg_abnormal(j, k) = 1;
            end
        end
    end

    %% 頻率變化偵測
    % band_change
    band_change = zeros(5, 6, epoch*30);
    for b = 1:5
        tplot = zeros(6, epoch*30);
        for c = 1:6
            % 10秒為一組，檢查第11秒的值有無突然的上升
            for k = 11:epoch*30-30
                segment = [];
                if k > 30 
                    count = 0;
                    for j = 1:30
                        if band_change(b, c, k-j) == 0
                            segment(end+1) = band(b, c , k-j);
                            count = count + 1;
                        end
                        if count == 10 
                            break;
                        end
                    end
                else
                    segment = band(b, c, k-10:k-1);
                end
                
                % 4倍標準差
                threshold = mean(segment) + std(segment)*4;
                tplot(c, k) = threshold;
                % 檢查第11秒
                if band(b, c, k) > threshold
                    % 往後檢查有幾秒持續大於threshold
                    % 若大於20秒則不算
                    count = 0;
                    for j = 1:30
                        if band(b, c, k+j) > threshold
                            count = count + 1;
                        else
                            count = 0;
                            break;
                        end
                    end
                    % 在矩陣中標記
                    if count <= 20
                        band_change(b, c, k:k+count) = 1;
                    end
                end
            end
            % 畫圖 5 * 6 (太多了)
        end
        % 畫圖 5 * 1 指定channels
%         figure();
%         hold on; grid on;
%         c = 6; % 指定要看哪個channels
%         plot(reshape(band(b, c, :), 1, []), 'DisplayName', 'power');
%         plot(tplot(c, :), 'DisplayName', 'threshold');
%         band_bar = bar(reshape(band_change(b, c, :), 1, [])*10, 'FaceColor', 'b', 'BarWidth', 1, 'DisplayName', 'arousal detect');
%         set(band_bar, 'FaceAlpha', 0.4);
%         arousal_bar = bar(arousal2020*10, 'FaceColor', 'r', 'BarWidth', 1, 'DisplayName', 'arousal answer');
%         set(arousal_bar, 'FaceAlpha', 0.4);
%         ylabel("Power");
%         xlabel("Time (s)");
%         title("band: "+string(b));

    end

    %% EMG震幅變化偵測
    emg_amp_change = zeros(1, epoch*30);
    emg_amp = exg_amplitude(9, :);
    tplot = zeros(epoch*30, 1);
    for k = 11:epoch*30-30
        segment = [];
        if k > 30 
            count = 0;
            for j = 1:30
                if emg_amp_change(k-j) == 0
                    segment(end+1) = emg_amp(k-j);
                    count = count + 1;
                end
                if count == 10 
                    break;
                end
            end
        else
            segment = emg_amp(k-10:k-1);
        end
        
        % 4倍標準差
        threshold = mean(segment) + std(segment)*4;
        tplot(k) = threshold;
        % 檢查第11秒
        if emg_amp(k) > threshold
            % 往後檢查有幾秒持續大於threshold
            % 若大於20秒則不算
            count = 0;
            for j = 1:30
                if emg_amp(k+j) > threshold
                    count = count + 1;
                else
                    count = 0;
                    break;
                end
            end
            % 在矩陣中標記
            if count <= 20
                emg_amp_change(k:k+count) = 1;
            end
        end
    end
    figure();
    hold on; grid on;
    plot(emg_amp, 'DisplayName', 'amplitude');
    plot(tplot, 'DisplayName', 'threshold');
    band_bar = bar(emg_amp_change*500, 'FaceColor', 'b', 'BarWidth', 1, 'DisplayName', 'arousal detect');
    set(band_bar, 'FaceAlpha', 0.4);
    arousal_bar = bar(arousal2020*500, 'FaceColor', 'r', 'BarWidth', 1, 'DisplayName', 'arousal answer');
    set(arousal_bar, 'FaceAlpha', 0.4);
    ylabel("Amplitude");
    xlabel("Time (s)");
    title("EMG震幅變化偵測");

    %% Arousal偵測 ver2
    % 將5個band整合，計算每秒下有delta、theta、alpha、beta、gamma分別在不同channels出現幾次(不計算出現abnormal的channel)
    arousal_bandsum = zeros(5, epoch*30);
    for b = 1:5
        for c = 1:6
            for j = 1:epoch*30
                if exg_abnormal(c,j) ~= 1 && band_change(b, c, j) == 1
                    arousal_bandsum(b, j) = arousal_bandsum(b, j) + 1;
                end
            end
        end
    end

    % 制定納入arousal的規則條件
    arousal_possible = arousal_bandsum;
    % 2 channels以上有同樣特徵才視為Arousal
    arousal_possible(arousal_possible <= 2) = 0;
    % 模糊化alpha、beta、gamma 因Arousal特性向後模糊1秒、3秒、3秒
    fuzzy_alpha = arousal_possible(3, :);
    fuzzy_beta = arousal_possible(4, :);
    fuzzy_gamma = arousal_possible(5, :);
    for j = 1:epoch*30-2
        if (arousal_possible(3, j) ~= 0) && (arousal_possible(3, j+1) == 0)
            fuzzy_alpha(j+1) = arousal_possible(3, j);
        end
        if (arousal_possible(4, j) ~= 0) && (arousal_possible(3, j+1) == 0)
            fuzzy_beta(j+1:j+3) = arousal_possible(4, j);
        end
        if (arousal_possible(5, j) ~= 0) && (arousal_possible(3, j+1) == 0)
            fuzzy_gamma(j+1:j+3) = arousal_possible(5, j);
        end
    end
    arousal_possible(3, :) = fuzzy_alpha;
    arousal_possible(4, :) = fuzzy_beta;
    arousal_possible(5, :) = fuzzy_gamma;
    
    
    arousal_detect = zeros(1, epoch*30);
    % 直接將目前有數值的band合併視為Arousal
    % 直接將EMG納入
    for j = 1:epoch*30
        if emg_amp_change(j) == 1
            % theta、alpha、beta、gamma
            if sum(arousal_possible(2:5, j)) >= 2
                arousal_detect(j) = 1;
            end
        end
    end

    % 檢查大於3秒小於15秒
    count = 0;
    for j = 1:epoch*30
        % 計算連續次數
        if arousal_detect(j) == 1
            count = count + 1;
        % 當連續結束則計算秒數
        else
            % 超出時間範圍則刪除
            if (count ~= 0) && (count < 3)
                arousal_detect(j-count:j-1) = 0;
            end
            count = 0;
        end
    end

    % 加入全部channels的abnormal區段
    for j = 1:epoch*30
        if sum(exg_abnormal(1:9, j)) >= 7
            arousal_detect(j) = 1;
        end
    end


    %% validation
    % confuse matrix
    % tp 成功偵測出apnea
    % tn 成功偵測出無事件(不考量)
    % fp 偵測錯誤
    % fn 漏抓
    tp = 0;
    fp = 0;
    fn = 0;
    
    count = 0;
    es = 0;
    ee = 0;
    for j = 1:length(arousal2020)
        if (arousal2020(j) == 1) && (count == 0)
            es = j;
            count = 1;
        elseif (arousal2020(j) == 0) && (count == 1)
            ee = j - 1;
            count = 0;
            if sum(arousal_detect(es:ee)) > 0
                tp = tp + 1;
            else
                fn = fn + 1;
            end
        end
    end
    for j = 1:length(arousal_detect)
        if (arousal_detect(j) == 1) && (count == 0)
            es = j;
            count = 1;
        elseif (arousal_detect(j) == 0) && (count == 1)
            ee = j - 1;
            count = 0;
            if sum(arousal2020(es:ee)) == 0
                fp = fp + 1;
            end
        end
    end
    
    % Sensitivity(TP/(TP+FN)) 真的能被檢測出來的比例
    % Precision(TP/(TP+FP)) 檢測的準確性
    sensitivity = tp / (tp+fn);
    precision = tp / (tp+fp);
    disp("sensitivity: "+string(sensitivity)+" precision: "+string(precision));
    
    %% 畫bands偵測圖
    figure();
    hold on; grid on;
    % 標準答案 紅
    arousal_bar = bar(arousal2020*6, 'FaceColor', 'r', 'BarWidth', 1);
    set(arousal_bar, 'FaceAlpha', 0.2);
    % 偵測答案 藍
    detect_bar = bar(arousal_detect*-1, 'FaceColor', 'b', 'BarWidth', 1);
    % 訊號異常 黑
    abnormal_bar = bar((sum(exg_abnormal) == 9)*6, 'FaceColor', 'k', 'BarWidth', 1);
    set(abnormal_bar, 'FaceAlpha', 0.2);
    % EMG
    plot(emg_amp./max(emg_amp));
    emg_bar = bar(emg_amp_change*-2, 'FaceColor', 'g', 'BarWidth', 1, 'DisplayName', 'emg');
    set(emg_bar, 'FaceAlpha', 0.2);
    % beta 綠
    beta_bar = bar((arousal_possible(4, :) ~= 0)*5, 'FaceColor', 'g', 'BarWidth', 1, 'DisplayName', 'beta');
    set(beta_bar, 'FaceAlpha', 0.2);
    % alpha 黃
    alpha_bar = bar((arousal_possible(3, :) ~= 0)*4, 'FaceColor', '#EDB120', 'BarWidth', 1, 'DisplayName', 'alpha');
    set(alpha_bar, 'FaceAlpha', 0.2);
    % gamma 紫
    gamma_bar = bar((arousal_possible(5, :) ~= 0)*3, 'FaceColor', 'm', 'BarWidth', 1, 'DisplayName', 'gamma');
    set(gamma_bar, 'FaceAlpha', 0.2);
    % theta 橘
    theta_bar = bar((arousal_possible(2, :) ~= 0)*2, 'FaceColor', '#D95319', 'BarWidth', 1, 'DisplayName', 'theta');
    set(theta_bar, 'FaceAlpha', 0.2);
    % delta 藍
    delta_bar = bar((arousal_possible(1, :) ~= 0)*1, 'FaceColor', 'b', 'BarWidth', 1, 'DisplayName', 'delta');
    set(delta_bar, 'FaceAlpha', 0.2);

    axis tight;
    ylim([0 30]);
    title("Arousal偵測圖");


    waitbar(i/filesNumber,h,strcat('Please wait...',num2str(round(i/filesNumber*100)),'%'))    
end
close(h);