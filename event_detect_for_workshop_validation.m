clear;
close all;

InputDir = '.\workshop0606data\rawdata\';
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

    %% filter lowpass
    npress = lowpass(npress, 2, 25);
    therm = lowpass(therm, 2, 25);
    thor = lowpass(thor, 2, 25);
    abdo = lowpass(abdo, 2, 25);

    %% find peaks

    % 設定npress的最小高度與最小間隔，抓取波峰與波谷 25為fs 3為秒數
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

    % figure();
    % plot((1:epoch*30*25), npress, upper_locs_npress, upper_pks_npress, 'or', lower_locs_npress, lower_pks_npress*-1, 'og');

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
        amplitude = upper_curve_thor(j*25) - lower_curve_thor(j*25);
        if amplitude <= 0
            amplitude = 0.0001;
        end
        second_matrix(3, j) = amplitude;
        amplitude = upper_curve_abdo(j*25) - lower_curve_abdo(j*25);
        if amplitude <= 0
            amplitude = 0.0001;
        end
        second_matrix(4, j) = amplitude;
        second_matrix(5, j) = spo2(j);
    end

    %% 驗證

    % OA CA MA OH CH MH SpO2
    event = load('G:\共用雲端硬碟\Sleep center data\auto_detection\respiratory_detect\workshop0606data\event\event.mat');
    aasm2020_event = zeros(7, epoch*30);
    for j = 1:length(event.event_name)
        if string(event.event_name(j)) == "Obstructive Apnea"
            mystart = seconds(cell2mat(event.event_second(j)));
            myduration = duration(event.event_duration(j), 'InputFormat', 'mm:ss.S');
            myend = mystart + myduration;
            for k = round(seconds(mystart)):round(seconds(myend))
                aasm2020_event(1, k) = 1;
            end
        end
    end


    %% 偵測演算法

    % Apnea_artifact、Apnea_type、Hypopnea_artifact、Hypopnea_type、SpO2_artifact、SpO2_Desat
    detect_matrix = zeros(6, epoch*30);

    %% Apnea (therm下降90%且大於10秒)
    s_therm = second_matrix(2, :);
    figure();
    plot(s_therm); hold on; grid on;
    plot(downsample(therm, 25));
    OA2020_bar = bar(aasm2020_event(1, :)*-1, 'FaceColor', 'r', 'BarWidth', 1);
    set(OA2020_bar, 'FaceAlpha', 0.2);
    title("Apnea detection");

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
                        no_breath = 0;
                        break;
                    end
                end
            end
        end
    end
    OAdetect_bar = bar(detect_matrix(2, :)*-2, 'FaceColor', 'r', 'BarWidth', 1);
    set(OAdetect_bar, 'FaceAlpha', 0.2);
    artifact_bar = bar(detect_matrix(1, :)*-2, 'FaceColor', 'k', 'BarWidth', 1);
    set(artifact_bar, 'FaceAlpha', 0.2);
    
    %% confuse matrix
    
    
    waitbar(i/filesNumber,h,strcat('Please wait...',num2str(round(i/filesNumber*100)),'%'))    
end
close(h);