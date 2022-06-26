
clear;
close all;

% 載入所有要偵測的檔案(.mat)位置
InputDir = 'G:\共用雲端硬碟\Sleep center data\auto_detection\sleep_scoring_AI\2022_Sleep_Scoring_AI\2022data\';
outputDir = 'G:\共用雲端硬碟\Sleep center data\auto_detection\respiratory_detect\2020respiratory_feature\';
goldenDir = 'G:\共用雲端硬碟\Sleep center data\auto_detection\sleep_scoring_AI\2022_Sleep_Scoring_AI\2022event\';

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

AHI_all = [xAHI_all, yAHI_all];

for i = 7

    fprintf('file(%d)\n', i);
    
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
    thor = data(14, :);
    thor = thor(1:epoch*30*25);
    abdo = data(15, :);
    abdo = abdo(1:epoch*30*25);
    spo2 = data(16, :);
    spo2 = spo2(1:epoch*30);
    
    % filter lowpass 先不要過filter好了，因為看起來影響不大，而且過filter訊號會平移，時間點要對齊
    % npress = lowpass(npress, 2, 25);
    % therm = lowpass(therm, 2, 25);

    %% 載入標準答案(以睡眠中心event格式)
    % OA、CA、MA、OH、CH、MH、SpO2、SpO2_Artifact、Arousal_res、Arousal_limb、Arousal_spont、Arousal_plm
    golden_event = zeros(12, epoch*30);
    golden_file = join([goldenDir, string(i), '.xlsx'], '');
    [fileType, sheets] = xlsfinfo(golden_file);
    % eventid、second、duration、para1、para2、para3、man_scored
    golden_data = xlsread(golden_file, string(sheets(1)));    
    for j = 1:height(golden_data)       
        if golden_data(j, 1) == 1 % CA
            golden_event(2, round(golden_data(j, 2))+1 : round(golden_data(j, 2) + golden_data(j, 3))+1) = 1;      
        elseif golden_data(j, 1) == 2 % OA
            golden_event(1, round(golden_data(j, 2))+1 : round(golden_data(j, 2) + golden_data(j, 3))+1) = 1;       
        elseif golden_data(j, 1) == 3 % MA
            golden_event(3, round(golden_data(j, 2))+1 : round(golden_data(j, 2) + golden_data(j, 3))+1) = 1;        
        elseif golden_data(j, 1) == 29 % OH
            golden_event(4, round(golden_data(j, 2))+1 : round(golden_data(j, 2) + golden_data(j, 3))+1) = 1;
        elseif golden_data(j, 1) == 30 % CH
            golden_event(5, round(golden_data(j, 2))+1 : round(golden_data(j, 2) + golden_data(j, 3))+1) = 1;        
        elseif golden_data(j, 1) == 31 % MH
            golden_event(6, round(golden_data(j, 2))+1 : round(golden_data(j, 2) + golden_data(j, 3))+1) = 1;        
        elseif golden_data(j, 1) == 4 % SpO2
            golden_event(7, round(golden_data(j, 2))+1 : round(golden_data(j, 2) + golden_data(j, 3))+1) = 1;        
        elseif golden_data(j, 1) == 7 % Arousal_res
            golden_event(9, round(golden_data(j, 2))+1 : round(golden_data(j, 2) + golden_data(j, 3))+1) = 1;        
        elseif golden_data(j, 1) == 8 % Arousal_limb
            golden_event(10, round(golden_data(j, 2))+1 : round(golden_data(j, 2) + golden_data(j, 3))+1) = 1;
        elseif golden_data(j, 1) == 9 % Arousal_spont
            golden_event(11, round(golden_data(j, 2))+1 : round(golden_data(j, 2) + golden_data(j, 3))+1) = 1;
        elseif golden_data(j, 1) == 10 % Arousal_plm
            golden_event(12, round(golden_data(j, 2))+1 : round(golden_data(j, 2) + golden_data(j, 3))+1) = 1;
        end
    end
    golden_event = golden_event(:, 1:epoch*30);
    
    %% find peaks

    % 設定npress的最小高度與最小間隔，抓取波峰與波谷 25為fs 2.6為秒數
    % 波峰
    [upper_pks_npress, upper_locs_npress] = findpeaks(npress, 'MinPeakDistance', 25*2.6);
    [upper_pks_therm, upper_locs_therm] = findpeaks(therm, 'MinPeakDistance', 25*2.6);
    [upper_pks_thor, upper_locs_thor] = findpeaks(thor, 'MinPeakDistance', 25*2.6);
    [upper_pks_abdo, upper_locs_abdo] = findpeaks(abdo, 'MinPeakDistance', 25*2.6);
    % 波谷 反轉訊號計算
    [lower_pks_npress, lower_locs_npress] = findpeaks(npress*-1, 'MinPeakDistance', 25*2.6);
    [lower_pks_therm, lower_locs_therm] = findpeaks(therm*-1, 'MinPeakDistance', 25*2.6);
    [lower_pks_thor, lower_locs_thor] = findpeaks(thor*-1, 'MinPeakDistance', 25*2.6);
    [lower_pks_abdo, lower_locs_abdo] = findpeaks(abdo*-1, 'MinPeakDistance', 25*2.6);
    
    %% curve fit 要安裝curve fitting toolbox
    smoothingparam = 0.0001;
    upper_curve_npress = fit(upper_locs_npress.', upper_pks_npress.', 'smoothingspline', 'SmoothingParam', smoothingparam);
    upper_curve_therm = fit(upper_locs_therm.', upper_pks_therm.', 'smoothingspline', 'SmoothingParam', smoothingparam);
    upper_curve_thor = fit(upper_locs_thor.', upper_pks_thor.', 'smoothingspline', 'SmoothingParam', smoothingparam);
    upper_curve_abdo = fit(upper_locs_abdo.', upper_pks_abdo.', 'smoothingspline', 'SmoothingParam', smoothingparam);
    lower_curve_npress = fit(lower_locs_npress.', (lower_pks_npress*-1).', 'smoothingspline', 'SmoothingParam', smoothingparam);
    lower_curve_therm = fit(lower_locs_therm.', (lower_pks_therm*-1).', 'smoothingspline', 'SmoothingParam', smoothingparam);
    lower_curve_thor = fit(lower_locs_thor.', (lower_pks_thor*-1).', 'smoothingspline', 'SmoothingParam', smoothingparam);
    lower_curve_abdo = fit(lower_locs_abdo.', (lower_pks_abdo*-1).', 'smoothingspline', 'SmoothingParam', smoothingparam);
    
    figure();
    plot((1:epoch*30*25), npress); hold on;
    plot(upper_curve_npress, 'r', upper_locs_npress, upper_pks_npress, 'ro');
    plot(lower_curve_npress, 'g', lower_locs_npress, lower_pks_npress*-1, 'go');
    apnea2020 = golden_event(1, :) | golden_event(2, :) | golden_event(3, :);
    npress_bar = bar(kron(apnea2020, ones(1, 25)), 'FaceColor', 'r', 'BarWidth', 1);
    set(npress_bar, 'FaceAlpha', 0.5);
    hypopnea2020 = golden_event(4, :) | golden_event(5, :) | golden_event(6, :);
    therm_bar = bar(kron(hypopnea2020, ones(1, 25)), 'FaceColor', 'b', 'BarWidth', 1);
    set(therm_bar, 'FaceAlpha', 0.5);
    title(string(i) + " npress");
    figure();
    plot((1:epoch*30*25), therm); hold on;
    plot(upper_curve_therm, 'r', upper_locs_therm, upper_pks_therm, 'ro');
    plot(lower_curve_therm, 'g', lower_locs_therm, lower_pks_therm*-1, 'go');
    apnea2020 = golden_event(1, :) | golden_event(2, :) | golden_event(3, :);
    npress_bar = bar(kron(apnea2020, ones(1, 25)), 'FaceColor', 'r', 'BarWidth', 1);
    set(npress_bar, 'FaceAlpha', 0.5);
    hypopnea2020 = golden_event(4, :) | golden_event(5, :) | golden_event(6, :);
    therm_bar = bar(kron(hypopnea2020, ones(1, 25)), 'FaceColor', 'b', 'BarWidth', 1);
    set(therm_bar, 'FaceAlpha', 0.5);
    title(string(i) + " therm");

    %% 計算震幅變化產生矩陣 矩陣數值恆正 最小值為0.0001

    % npress震幅、therm震幅、thor震幅、abdo震幅、spo2
%     second_matrix = zeros(5, epoch*30);
% 
%     for j = 1:epoch*30
%         amplitude = upper_curve_npress(j*25) - lower_curve_npress(j*25);
%         if amplitude <= 0
%             amplitude = 0.0001;
%         end
%         second_matrix(1, j) = amplitude;
%         amplitude = upper_curve_therm(j*25) - lower_curve_therm(j*25);
%         if amplitude <= 0
%             amplitude = 0.0001;
%         end
%         second_matrix(2, j) = amplitude;
%         amplitude = upper_curve_thor(j*25) - lower_curve_thor(j*25);
%         if amplitude <= 0
%             amplitude = 0.0001;
%         end
%         second_matrix(3, j) = amplitude;
%         amplitude = upper_curve_abdo(j*25) - lower_curve_abdo(j*25);
%         if amplitude <= 0
%             amplitude = 0.0001;
%         end
%         second_matrix(4, j) = amplitude;
%         second_matrix(5, j) = spo2(j);
%     end
    
    %csvwrite(join([outputDir, string(i), '.csv'], ''), second_matrix);

end
