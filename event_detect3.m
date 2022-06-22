% 整合 Arousal 呼吸事件 SpO2 偵測
clear;
close all;

% 載入所有要偵測的檔案(.mat)位置
InputDir = 'G:\共用雲端硬碟\Sleep center data\auto_detection\sleep_scoring_AI\2022_Sleep_Scoring_AI\2022data\';
files = dir([InputDir '*.mat']); %load all .mat files in the folder
% 載入標準答案(.csv)的位置
goldenDir = 'G:\共用雲端硬碟\Sleep center data\auto_detection\sleep_scoring_AI\2022_Sleep_Scoring_AI\2022event\';

apnea_recall = [];
apnea_precision = [];
hypopnea_recall = [];
hypopnea_precision = [];
spo2_recall = [];
spo2_precision = [];

% AHI奇數
xAHI_all = [39,102,52,47,105,103,2,9,4,3,28,34,69,65,27,78,81,...
            44,113,1,62,108,32,75,33,37,67,117,6,43,89,15,97,71,...
            17,12,85,49,38,79,86,94,41,11,80,10,30,29,107,109,...
            16,5,91,35,20,95,92,70,74,93];

% AHI偶數
yAHI_all = [60,96,53,76,48,25,66,18,19,114,45,58,104,63,61,115,72,...
            21,13,59,98,56,100,55,73,31,22,99,110,111,87,50,106,...
            84,82,23,64,77,83,119,57,26,90,118,8,116,36,88,51,112,...
            46,42,14,24,120,7,54,40,101,68];

%h = waitbar(0,'Please wait...');
filesNumber = length(files);
for i = xAHI_all

    fprintf('file(%d/%d)\n', i, filesNumber);
    
    %% channel 12:NPress 13:Therm 14:Thor 15:Abdo 16:SpO2

    % 分析訊號 注意channels到底對不對
    data = load(join([InputDir, string(i), '.mat'], ''));
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
   
    % 載入標準答案 (以睡眠中心event格式)
    % OA、CA、MA、OH、CH、MH、SpO2、SpO2_Artifact、Arousal_res、Arousal_limb、Arousal_spont、Arousal_plm
    golden_event = zeros(12, epoch*30);
    golden_file = join([goldenDir, string(i), '.xlsx'], '');
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
    golden_event = golden_event(:, 1:epoch*30);
    
    
    % filter lowpass 先不要過filter好了，因為看起來影響不大，而且過filter訊號會平移，時間點要對齊
    % npress = lowpass(npress, 2, 25);
    % therm = lowpass(therm, 2, 25);
    
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
    for j = 1:length(s_therm)-180
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
%             if (sum(arousal_detect(j-10:j+10)) == 0) && (sum(detect_matrix(6, j-10:j+10)) == 0)
%                 detect_matrix(4, j-count:j-1) = 0;
%             end
            count = 0;
        end
    end
    
    % 計算 apnea recall precision
    my_apena = detect_matrix(2, :);
    apnea2020 = golden_event(1, :) | golden_event(2, :) | golden_event(3, :);

    tp = 0;
    fn = 0;
    fp = 0;
    
    cont = 0;
    es = 0;
    ee = 0;
    for j = 1:length(apnea2020)
        if (apnea2020(j) == 1) && (cont == 0)
            es = j;
            cont = 1;
        elseif (apnea2020(j) == 0) && (cont == 1)
            ee = j - 1;
            cont = 0;
            if sum(my_apena(es:ee)) > 0
                tp = tp + 1;
            else
                fn = fn + 1;
            end
        end
    end
    for j = 1:length(my_apena)
        if (my_apena(j) == 1) && (cont == 0)
            es = j;
            cont = 1;
        elseif (my_apena(j) == 0) && (cont == 1)
            ee = j - 1;
            cont = 0;
            if sum(apnea2020(es:ee)) == 0
                fp = fp + 1;
            end
        end
    end

    recall = tp/(tp+fn);
    precision = tp/(tp+fp);
    apnea_recall(end+1) = recall;
    apnea_precision(end+1) = precision;
    disp("file " + string(i) + "  Apnea  recall: " + string(recall) + " precision: " + string(precision));

    % 計算 hypopnea recall precision
    my_hypopnea = detect_matrix(4, :);
    hypopnea2020 = golden_event(4, :) | golden_event(5, :) | golden_event(5, :);

    tp = 0;
    fn = 0;
    fp = 0;
    
    cont = 0;
    es = 0;
    ee = 0;
    for j = 1:length(hypopnea2020)
        if (hypopnea2020(j) == 1) && (cont == 0)
            es = j;
            cont = 1;
        elseif (hypopnea2020(j) == 0) && (cont == 1)
            ee = j - 1;
            cont = 0;
            if sum(my_hypopnea(es:ee)) > 0
                tp = tp + 1;
            else
                fn = fn + 1;
            end
        end
    end
    for j = 1:length(my_hypopnea)
        if (my_hypopnea(j) == 1) && (cont == 0)
            es = j;
            cont = 1;
        elseif (my_hypopnea(j) == 0) && (cont == 1)
            ee = j - 1;
            cont = 0;
            if sum(hypopnea2020(es:ee)) == 0
                fp = fp + 1;
            end
        end
    end

    recall = tp/(tp+fn);
    precision = tp/(tp+fp);
    hypopnea_recall(end+1) = recall;
    hypopnea_precision(end+1) = precision;
    disp("file " + string(i) + "  Hypopnea  recall: " + string(recall) + " precision: " + string(precision));

    % 計算 spo2 recall precision
    my_spo2 = detect_matrix(6, :);
    spo22020 = golden_event(7, :);

    tp = 0;
    fn = 0;
    fp = 0;
    
    cont = 0;
    es = 0;
    ee = 0;
    for j = 1:length(spo22020)
        if (spo22020(j) == 1) && (cont == 0)
            es = j;
            cont = 1;
        elseif (spo22020(j) == 0) && (cont == 1)
            ee = j - 1;
            cont = 0;
            if sum(my_spo2(es:ee)) > 0
                tp = tp + 1;
            else
                fn = fn + 1;
            end
        end
    end
    for j = 1:length(my_spo2)
        if (my_spo2(j) == 1) && (cont == 0)
            es = j;
            cont = 1;
        elseif (my_spo2(j) == 0) && (cont == 1)
            ee = j - 1;
            cont = 0;
            if sum(spo22020(es:ee)) == 0
                fp = fp + 1;
            end
        end
    end

    recall = tp/(tp+fn);
    precision = tp/(tp+fp);
    spo2_recall(end+1) = recall;
    spo2_precision(end+1) = precision;
    disp("file " + string(i) + "  SpO2  recall: " + string(recall) + " precision: " + string(precision));

end

disp("total Apnea recall: " + string(mean(apnea_recall)) + " total Apnea precision: " + string(mean(apnea_precision)));
disp("total Hypopnea recall: " + string(mean(hypopnea_recall)) + " total Hypopnea precision: " + string(mean(hypopnea_precision)));
disp("total SpO2 recall: " + string(mean(spo2_recall)) + " total SpO2 precision: " + string(mean(spo2_precision)));
