% 整合 Arousal 呼吸事件 SpO2 偵測
clear;
close all;

% 載入所有要偵測的檔案(.mat)位置
InputDir = '.\2022data\data\';
files = dir([InputDir '*.mat']); %load all .mat files in the folder
% 載入標準答案(.csv)的位置
goldenDir = '.\2022data\answer\';
% 匯出偵測結果(.csv)的位置
OutputDir = '.\2022data\result\';

h = waitbar(0,'Please wait...');
filesNumber = length(files);
for i = 1 : filesNumber
    close all;
    fprintf('file(%d/%d): %s is loaded.\n', i, filesNumber, files(i).name(1:end-4));
    
    %% channel 12:NPress 13:Therm 14:Thor 15:Abdo 16:SpO2

    % 分析訊號 注意channels到底對不對
    data = load(fullfile(files(i).folder,files(i).name));
    fs = 200; %睡眠中心 sample rate
    data = data.data;

    % c3m2、c4m1、f3m2、f4m1、o1m2、o2m1、e1m2、e2m1、emgr
    exg = data(1:9, :);
    epoch = floor((width(exg) / fs) / 30);

    npress = data(12, :);
    npress = npress(1:epoch*30*25);
    therm = data(13, :);
    therm = therm(1:epoch*30*25);
    %thor = data(14, :);
    %thor = thor(1:epoch*30*25);
    %abdo = data(15, :);
    %abdo = abdo(1:epoch*30*25);
    spo2 = data(16, :);
    spo2 = spo2(1:epoch*30);
   
    %% 載入標準答案 (以判讀網頁event為格式，睡眠中心event則不適用，需經過轉換)
    % OA、CA、MA、OH、CH、MH、SpO2、SpO2_Artifact、Arousal_res、Arousal_limb、Arousal_spont、Arousal_plm
    golden_event = zeros(12, epoch*30);
    golden_file = [goldenDir, files(i).name(1:end-4), '.xlsx'];
    [fileType, sheets] = xlsfinfo(golden_file);
    % eventid、second、duration、para1、para2、para3、man_scored
    golden_data = xlsread(golden_file, string(sheets(1)));
    
    for j = 1:height(golden_data)
        % OA
        if golden_data(j, 1) == 2 && golden_data(j, 7) == 1
            golden_event(1, round(golden_data(j, 2)) : round(golden_data(j, 2) + golden_data(j, 3))) = 1;
        % CA
        elseif golden_data(j, 1) == 1 && golden_data(j, 7) == 1
            golden_event(2, round(golden_data(j, 2)) : round(golden_data(j, 2) + golden_data(j, 3))) = 1;
        % MA
        elseif golden_data(j, 1) == 3 && golden_data(j, 7) == 1
            golden_event(3, round(golden_data(j, 2)) : round(golden_data(j, 2) + golden_data(j, 3))) = 1;
        % OH
        elseif golden_data(j, 1) == 29 && golden_data(j, 7) == 1
            golden_event(4, round(golden_data(j, 2)) : round(golden_data(j, 2) + golden_data(j, 3))) = 1;
        % CH
        elseif golden_data(j, 1) == 30 && golden_data(j, 7) == 1
            golden_event(5, round(golden_data(j, 2)) : round(golden_data(j, 2) + golden_data(j, 3))) = 1;
        % MH
        elseif golden_data(j, 1) == 31 && golden_data(j, 7) == 1
            golden_event(6, round(golden_data(j, 2)) : round(golden_data(j, 2) + golden_data(j, 3))) = 1;
        % SpO2 Desat
        elseif golden_data(j, 1) == 4
            golden_event(7, round(golden_data(j, 2)) : round(golden_data(j, 2) + golden_data(j, 3))) = 1;
        % SpO2 Artifact
        elseif golden_data(j, 1) == 6 && golden_data(j, 7) == 1
            golden_event(8, round(golden_data(j, 2)) : round(golden_data(j, 2) + golden_data(j, 3))) = 1;
        % Arousal_res
        elseif golden_data(j, 1) == 7 && golden_data(j, 7) == 1
            golden_event(9, round(golden_data(j, 2)) : round(golden_data(j, 2) + golden_data(j, 3))) = 1;
        % Arousal_limb
        elseif golden_data(j, 1) == 8 && golden_data(j, 7) == 1
            golden_event(10, round(golden_data(j, 2)) : round(golden_data(j, 2) + golden_data(j, 3))) = 1;
        % Arousal_spont
        elseif golden_data(j, 1) == 9 && golden_data(j, 7) == 1
            golden_event(11, round(golden_data(j, 2)) : round(golden_data(j, 2) + golden_data(j, 3))) = 1;
        % Arousal_plm
        elseif golden_data(j, 1) == 10 && golden_data(j, 7) == 1
            golden_event(12, round(golden_data(j, 2)) : round(golden_data(j, 2) + golden_data(j, 3))) = 1;
        end
    end
    
    %% Arousal分析
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

    % 計算每2秒震幅大小 overlap 1秒 才能抓到delta wave?
    exg_amplitude = zeros(9, epoch*30);
    for j = 1:height(exg)
        for k = 1:epoch*30
            segment = exg(j, (k-1)*fs+1:(k-1)*fs+fs*2);
            exg_amplitude(j,k) = max(segment) - min(segment);
        end
    end

    % 定義訊號異常矩陣 超過threshold視為abnormal
    threshold = 300; % for eeg 還要再細分
    exg_abnormal = zeros(9, epoch*30);
    for j = 1:height(exg_amplitude)
        for k = 1:epoch*30
            if exg_amplitude(j, k) >= threshold
                exg_abnormal(j, k) = 1;
            end
        end
    end
    
    %% 頻率變化偵測
    band_change = zeros(5, 6, epoch*30);
    for b = 1:5
        % 畫圖用
        %tplot = zeros(6, epoch*30);
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
                %tplot(c, k) = threshold;
                % 檢查第11秒
                if band(b, c, k) > threshold
                    % 往後檢查有幾秒持續大於threshold，若大於20秒則不算
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
        end
    end
    
    %% EMG震幅變化偵測
    emg_amp_change = zeros(1, epoch*30);
    emg_amp = exg_amplitude(9, :);
    % 畫圖用
    %tplot = zeros(epoch*30, 1);
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
        %tplot(k) = threshold;
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
    
    % 最終的Arousal偵測結果，之後會加入判斷依據的參數
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
    
    %% 進入呼吸事件環節
    
    % filter lowpass 先不要過filter好了，因為看起來影響不大，而且過filter訊號會平移，時間點要對齊
    %npress = lowpass(npress, 2, 25);
    %therm = lowpass(therm, 2, 25);
    
    %% find peaks

    % 設定npress的最小高度與最小間隔，抓取波峰與波谷 25為fs 2.6為秒數
    % 波峰
    [upper_pks_npress, upper_locs_npress] = findpeaks(npress, 'MinPeakDistance', 25*2.6);
    [upper_pks_therm, upper_locs_therm] = findpeaks(therm, 'MinPeakDistance', 25*2.6);
    % [upper_pks_thor, upper_locs_thor] = findpeaks(thor, 'MinPeakDistance', 25*2.6);
    % [upper_pks_abdo, upper_locs_abdo] = findpeaks(abdo, 'MinPeakDistance', 25*2.6);
    % 波谷 反轉訊號計算
    [lower_pks_npress, lower_locs_npress] = findpeaks(npress*-1, 'MinPeakDistance', 25*2.6);
    [lower_pks_therm, lower_locs_therm] = findpeaks(therm*-1, 'MinPeakDistance', 25*2.6);
    % [lower_pks_thor, lower_locs_thor] = findpeaks(thor*-1, 'MinPeakDistance', 25*2.6);
    % [lower_pks_abdo, lower_locs_abdo] = findpeaks(abdo*-1, 'MinPeakDistance', 25*2.6);
    
    %% curve fit 要安裝curve fitting toolbox
    smoothingparam = 0.0001;
    upper_curve_npress = fit(upper_locs_npress.', upper_pks_npress.', 'smoothingspline', 'SmoothingParam', smoothingparam);
    upper_curve_therm = fit(upper_locs_therm.', upper_pks_therm.', 'smoothingspline', 'SmoothingParam', smoothingparam);
    % upper_curve_thor = fit(upper_locs_thor.', upper_pks_thor.', 'smoothingspline', 'SmoothingParam', smoothingparam);
    % upper_curve_abdo = fit(upper_locs_abdo.', upper_pks_abdo.', 'smoothingspline', 'SmoothingParam', smoothingparam);
    lower_curve_npress = fit(lower_locs_npress.', (lower_pks_npress*-1).', 'smoothingspline', 'SmoothingParam', smoothingparam);
    lower_curve_therm = fit(lower_locs_therm.', (lower_pks_therm*-1).', 'smoothingspline', 'SmoothingParam', smoothingparam);
    % lower_curve_thor = fit(lower_locs_thor.', (lower_pks_thor*-1).', 'smoothingspline', 'SmoothingParam', smoothingparam);
    % lower_curve_abdo = fit(lower_locs_abdo.', (lower_pks_abdo*-1).', 'smoothingspline', 'SmoothingParam', smoothingparam);
    
    %% 計算震幅變化產生矩陣 矩陣數值恆正 最小值為0.0001

    % npress震幅、therm震幅、thor震幅、abdo震幅、spo2
    second_matrix = zeros(5, epoch*30);

    for j = 1:epoch*30
        amplitude = upper_curve_npress(j*25) - lower_curve_npress(j*25);
        if amplitude <= 0
            amplitude = 0.0001;
        end
        second_matrix(1, j) = amplitude;
        amplitude = upper_curve_therm(j*25) - lower_curve_therm(j*25);
        if amplitude <= 0
            amplitude = 0.0001;
        end
        second_matrix(2, j) = amplitude;
        second_matrix(5, j) = spo2(j);
    end
    
    %% 呼吸事件偵測演算法
    % Apnea_artifact、Apnea_type、Hypopnea_artifact、Hypopnea_type、SpO2_artifact、SpO2_Desat
    detect_matrix = zeros(6, epoch*30);
    
    %% Apnea (therm下降90%且大於10秒)
    s_therm = second_matrix(2, :);
    
    % Artifact檢查 大於120s無呼吸 threshold 0.3
    no_breath = 0;
    for j = 1:length(s_therm)
        if s_therm(j) <= 0.3
            no_breath = no_breath + 1;
        else
            if no_breath >= 180
                detect_matrix(1, j-no_breath:j) = 1;
            end
            no_breath = 0;
        end
    end

    % 連續檢查30s有無下降90%且最小值小於 threshold 1
    windows = 30;
    threshold = 1;
    for j = 1:length(s_therm)-windows
        % 無artifact且尚未經過Apnea檢查
        if detect_matrix(1, j) ~= 1 && detect_matrix(2, j) ~= 1
            [lmax, imax] = max(s_therm(j:j+windows));
            [lmin, imin] = min(s_therm(j:j+windows));
            % 最小值小於threshold且下降超過90%
            if lmin < threshold && (lmin / lmax) < 0.1
                % 向後檢查是否持續小於90%
                no_breath = 0;
                for k = 1:180
                    if (s_therm(j+imin-1+k) / lmax) < 0.1
                        no_breath = no_breath + 1;
                    else
                        % 超過10秒標記為Apnea
                        if no_breath >= 10
                            detect_matrix(2, j+imin-1:j+imin-1+no_breath) = 1;
                        end
                        break;
                    end
                end
            end
        end
    end
    
    %% SpO2 Desaturation
    s_spo2 = second_matrix(5, :);
    % Artifact檢查 小於10 大於100
    for j = 1:length(s_spo2)
        if s_spo2(j) <= 10 || s_spo2(j) > 100
            detect_matrix(5, j) = 1;
        end
    end

    % 檢查小於3%區間
    desat = 0;
    decrease = 0;
    last_spo2 = s_spo2(1);
    for j = 2:length(s_spo2)
        if detect_matrix(5, j) ~= 1
            % 持續下降
            if s_spo2(j) == last_spo2
                decrease = decrease + 1;
            % 持續下降
            elseif s_spo2(j) < last_spo2
                desat = desat + (last_spo2 - s_spo2(j));
                decrease = decrease + 1;
                last_spo2 = s_spo2(j);
            % 上升
            else
                if desat >= 3
                    detect_matrix(6, j-decrease:j-1) = 1;
                end
                desat = 0;
                decrease = 0;
                last_spo2 = s_spo2(j);
            end
        else
            desat = 0;
            decrease = 0;
        end
    end
    
     %% Hypopnea (npress下降30%且大於10秒並伴隨血氧下降3%或Arousal，且不是Apnea)
    s_npress = second_matrix(1, :);

    % Artifact檢查 大於120s無呼吸 threshold 0.3
    no_breath = 0;
    for j = 1:length(s_npress)
        if s_npress(j) <= 0.3
            no_breath = no_breath + 1;
        else
            if no_breath >= 180
                detect_matrix(3, j-no_breath:j) = 1;
            end
            no_breath = 0;
        end
    end

    % 連續檢查60s有無下降40%且最小值小於 threshold 0.5
    windows = 60;
    threshold = 0.5;
    for j = 1:length(s_npress)-240
        % 無artifact且尚未經過Hypopnea檢查
        if detect_matrix(3, j) ~= 1 && detect_matrix(4, j) ~= 1
            [lmax, imax] = max(s_npress(j:j+windows));
            [lmin, imin] = min(s_npress(j:j+windows));
            % 最小值小於threshold且下降超過30%
            if (lmin < threshold) && ((lmin / lmax) < 0.8)
                % 向後檢查是否持續小於30%
                no_breath = 0;
                for k = 1:180
                    if (s_npress(j+imin-1+k) / lmax) < 0.8
                        no_breath = no_breath + 1;
                    else
                        % 超過10秒標記為Hypopnea
                        if no_breath >= 10
                            detect_matrix(4, j+imin-1:j+imin-1+no_breath) = 1;
                        end
                        no_breath = 0;
                        break;
                    end
                end
            end
        end
    end
    
    count = 0;
    for j = 11:epoch*30-11
        % 計算連續次數
        if detect_matrix(4, j) == 1
            count = count + 1;
        % 當連續結束則檢查apnea、arousal、spo2
        else
            % 檢查是否跨到apnea範圍，是的話增加apnea範圍，刪除hypopnea
            if sum(detect_matrix(2, j-10:j+10)) ~= 0
                detect_matrix(2, j-10:j+10) = 1;
                detect_matrix(4, j-count:j-1) = 0;
            end
            % 檢查範圍前後10秒有無arousal、spo2 desat
            if (sum(arousal_detect(j-10:j+10)) == 0) && (sum(detect_matrix(6, j-10:j+10)) == 0)
                detect_matrix(4, j-count:j-1) = 0;
            end
            count = 0;
        end
    end
    
    %% 儲存偵測結果 (每秒矩陣csv)
    combine_matrix = [detect_matrix; arousal_detect];
    csvwrite([OutputDir, files(i).name(1:end-4), '.csv'], combine_matrix);
    
    waitbar(i/filesNumber,h,strcat('Please wait...',num2str(round(i/filesNumber*100)),'%'))    
end
close(h);