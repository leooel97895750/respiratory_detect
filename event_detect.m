clear;
close all;

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

    %% filter lowpass
    npress = lowpass(npress, 2, 25);
    therm = lowpass(therm, 2, 25);
    thor = lowpass(thor, 2, 25);
    abdo = lowpass(abdo, 2, 25);

    % figure();
    % subplot(5, 1, 1);
    % plot((1:epoch*30*25), npress);
    % title("NPress");
    % subplot(5, 1, 2);
    % plot((1:epoch*30*25), therm);
    % title("Therm");
    % subplot(5, 1, 3);
    % plot((1:epoch*30*25), thor);
    % title("Thor");
    % subplot(5, 1, 4);
    % plot((1:epoch*30*25), abdo);
    % title("Abdo");
    % subplot(5, 1, 5);
    % plot((1:epoch*30), spo2);
    % title("SpO2");

    %% emd分解
    % [imf,residual,info] = emd(npress,'MaxNumIMF', 4);
    % figure();
    % hht(imf, 25);
    % figure();
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

    % figure();
    % plot((1:epoch*30*25), npress); hold on;
    % plot(upper_curve_npress, 'r', upper_locs_npress, upper_pks_npress, 'ro');
    % plot(lower_curve_npress, 'g', lower_locs_npress, lower_pks_npress*-1, 'go');
    % title("NPress Findpeaks and Curve fitting");
    % figure();
    % plot((1:epoch*30*25), therm); hold on;
    % plot(upper_curve_therm, 'r', upper_locs_therm, upper_pks_therm, 'ro');
    % plot(lower_curve_therm, 'g', lower_locs_therm, lower_pks_therm*-1, 'go');
    % title("Therm Findpeaks and Curve fitting");
    % figure();
    % plot((1:epoch*30*25), thor); hold on;
    % plot(upper_curve_thor, 'r', upper_locs_thor, upper_pks_thor, 'ro');
    % plot(lower_curve_thor, 'g', lower_locs_thor, lower_pks_thor*-1, 'go');
    % title("Thor Findpeaks and Curve fitting");
    % figure();
    % plot((1:epoch*30*25), abdo); hold on;
    % plot(upper_curve_abdo, 'r', upper_locs_abdo, upper_pks_abdo, 'ro');
    % plot(lower_curve_abdo, 'g', lower_locs_abdo, lower_pks_abdo*-1, 'go');
    % title("Abdo Findpeaks and Curve fitting");

    % figure(); hold on;
    % uc_npress = plot(upper_curve_npress, 'r', upper_locs_npress, upper_pks_npress, 'w');
    % lc_npress = plot(lower_curve_npress, 'g', lower_locs_npress, lower_pks_npress*-1, 'w');
    % set(uc_npress, 'linewidth', 2);
    % set(lc_npress, 'linewidth', 2);
    % title("NPress Envelope");
    % figure(); hold on;
    % uc_therm = plot(upper_curve_therm, 'r', upper_locs_therm, upper_pks_therm, 'w');
    % lc_therm = plot(lower_curve_therm, 'g', lower_locs_therm, lower_pks_therm*-1, 'w');
    % set(uc_therm, 'linewidth', 2);
    % set(lc_therm, 'linewidth', 2);
    % title("Therm Envelope");
    % figure(); hold on;
    % uc_thor = plot(upper_curve_thor, 'r', upper_locs_thor, upper_pks_thor, 'w');
    % lc_thor = plot(lower_curve_thor, 'g', lower_locs_thor, lower_pks_thor*-1, 'w');
    % set(uc_thor, 'linewidth', 2);
    % set(lc_thor, 'linewidth', 2);
    % title("Thor Envelope");
    % figure(); hold on;
    % uc_abdo = plot(upper_curve_abdo, 'r', upper_locs_abdo, upper_pks_abdo, 'w');
    % lc_abdo = plot(lower_curve_abdo, 'g', lower_locs_abdo, lower_pks_abdo*-1, 'w');
    % set(uc_abdo, 'linewidth', 2);
    % set(lc_abdo, 'linewidth', 2);
    % title("Abdo Envelope");

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

    % 畫出: 原訊號、震幅變化、2013AASM標示處、2020AASM標示處
    aasm2013 = readtable('.\2022data\20191018_徐O文_2013aasm.csv');
    aasm2020 = readtable('.\2022data\20191018_徐O文_2020aasm.csv');

    % OA CA MA OH CH MH
    aasm2013_event = zeros(6, epoch*30);
    aasm2020_event = zeros(6, epoch*30);

    for j = 1:height(aasm2013)
        if string(aasm2013(j, 1).Var1) == "OA"
            aasm2013_event(1, round(aasm2013(j, 2).Var2) : round(aasm2013(j, 2).Var2 + aasm2013(j, 3).Var3)) = 1;
        elseif string(aasm2013(j, 1).Var1) == "CA"
            aasm2013_event(2, round(aasm2013(j, 2).Var2) : round(aasm2013(j, 2).Var2 + aasm2013(j, 3).Var3)) = 1;
        elseif string(aasm2013(j, 1).Var1) == "MA"
            aasm2013_event(3, round(aasm2013(j, 2).Var2) : round(aasm2013(j, 2).Var2 + aasm2013(j, 3).Var3)) = 1;
        elseif string(aasm2013(j, 1).Var1) == "OH"
            aasm2013_event(4, round(aasm2013(j, 2).Var2) : round(aasm2013(j, 2).Var2 + aasm2013(j, 3).Var3)) = 1;
        elseif string(aasm2013(j, 1).Var1) == "CH"
            aasm2013_event(5, round(aasm2013(j, 2).Var2) : round(aasm2013(j, 2).Var2 + aasm2013(j, 3).Var3)) = 1;
        elseif string(aasm2013(j, 1).Var1) == "MH"
            aasm2013_event(6, round(aasm2013(j, 2).Var2) : round(aasm2013(j, 2).Var2 + aasm2013(j, 3).Var3)) = 1;
        end
    end
    for j = 1:height(aasm2020)
        if string(aasm2020(j, 1).Var1) == "OA"
            aasm2020_event(1, round(aasm2020(j, 2).Var2) : round(aasm2020(j, 2).Var2 + aasm2020(j, 3).Var3)) = 1;
        elseif string(aasm2020(j, 1).Var1) == "CA"
            aasm2020_event(2, round(aasm2020(j, 2).Var2) : round(aasm2020(j, 2).Var2 + aasm2020(j, 3).Var3)) = 1;
        elseif string(aasm2020(j, 1).Var1) == "MA"
            aasm2020_event(3, round(aasm2020(j, 2).Var2) : round(aasm2020(j, 2).Var2 + aasm2020(j, 3).Var3)) = 1;
        elseif string(aasm2020(j, 1).Var1) == "OH"
            aasm2020_event(4, round(aasm2020(j, 2).Var2) : round(aasm2020(j, 2).Var2 + aasm2020(j, 3).Var3)) = 1;
        elseif string(aasm2020(j, 1).Var1) == "CH"
            aasm2020_event(5, round(aasm2020(j, 2).Var2) : round(aasm2020(j, 2).Var2 + aasm2020(j, 3).Var3)) = 1;
        elseif string(aasm2020(j, 1).Var1) == "MH"
            aasm2020_event(6, round(aasm2020(j, 2).Var2) : round(aasm2020(j, 2).Var2 + aasm2020(j, 3).Var3)) = 1;
        end
    end

    %% 偵測演算法

    % artifact、Apnea、Hypopnea、Desat
    detect_matrix = zeros(4, epoch*30);

    % Apnea (therm下降90%且大於10秒)
    s_therm = second_matrix(2, :);
    figure();
    plot(s_therm); hold on; grid on;
    OA2020_bar = bar(aasm2020_event(1, :)*-2, 'FaceColor', 'r', 'BarWidth', 1);
    set(OA2020_bar, 'FaceAlpha', 0.2);
    CA2020_bar = bar(aasm2020_event(2, :)*-2, 'FaceColor', 'g', 'BarWidth', 1);
    set(CA2020_bar, 'FaceAlpha', 0.2);
    MA2020_bar = bar(aasm2020_event(3, :)*-2, 'FaceColor', 'm', 'BarWidth', 1);
    set(MA2020_bar, 'FaceAlpha', 0.2);
    title("s_therm");


    % Artifact檢查 大於120s無呼吸 threshold 0.3
    no_breath = 0;
    for j = 1:length(s_therm)
        if s_therm(j) <= 0.3
            no_breath = no_breath + 1;
        else
            if no_breath >= 120
                detect_matrix(1, j-no_breath:j) = 1;
            end
            no_breath = 0;
        end
    end

    % 連續檢查10s有無下降90%且最小值小於 threshold 1
    no_breath = 0;
    for j = 1:length(s_therm)-10
        % 無artifact且尚未經過Apnea檢查
        if detect_matrix(1, j) ~= 1 && detect_matrix(2, j) ~= 1
            lmax = max(s_therm(j:j+10));
            lmin = min(s_therm(j:j+10));
            if lmin < 1 && (lmin / lmax) < 0.1
    
            end
        end
    end

%     offset = 5; % 前5秒與後5秒的震幅變化百分比，偵測時index要右移8單位
%     s_therm_per = zeros(1, length(s_therm)-offset*2+1);
%     for j = 1:length(s_therm)-offset*2
%         percentage = mean(s_therm(j+offset+1:j+offset*2)) / mean(s_therm(j:j+offset));
%         s_therm_per(1, j) = percentage; 
%     end
% 
%     plot(s_therm_per);


    % Hypopnea (npress下降30%且大於10秒並伴隨血氧下降3%或Arousal，且不是Apnea)
    s_npress = second_matrix(1, :);
    figure();
    plot(s_npress); hold on; grid on;
    OH2020_bar = bar(aasm2020_event(4, :)*-2, 'FaceColor', 'b', 'BarWidth', 1);
    set(OH2020_bar, 'FaceAlpha', 0.2);
    CH2020_bar = bar(aasm2020_event(5, :)*-2, 'FaceColor', 'c', 'BarWidth', 1);
    set(CH2020_bar, 'FaceAlpha', 0.2);
    MH2020_bar = bar(aasm2020_event(6, :)*-2, 'FaceColor', 'k', 'BarWidth', 1);
    set(MH2020_bar, 'FaceAlpha', 0.2);
    title("s_npress");

    %% 原訊號
    % NPress
    figure();
    plot(second_matrix(1, :)); hold on; grid on;
    plot(downsample(npress, 25));
    OA2013_bar = bar(aasm2013_event(1, :)*-1, 'FaceColor', 'r', 'BarWidth', 1);
    set(OA2013_bar, 'FaceAlpha', 0.2);
    CA2013_bar = bar(aasm2013_event(2, :)*-1, 'FaceColor', 'g', 'BarWidth', 1);
    set(CA2013_bar, 'FaceAlpha', 0.2);
    MA2013_bar = bar(aasm2013_event(3, :)*-1, 'FaceColor', 'm', 'BarWidth', 1);
    set(MA2013_bar, 'FaceAlpha', 0.2);
    OH2013_bar = bar(aasm2013_event(4, :)*-1, 'FaceColor', 'b', 'BarWidth', 1);
    set(OH2013_bar, 'FaceAlpha', 0.2);
    CH2013_bar = bar(aasm2013_event(5, :)*-1, 'FaceColor', 'c', 'BarWidth', 1);
    set(CH2013_bar, 'FaceAlpha', 0.2);
    MH2013_bar = bar(aasm2013_event(6, :)*-1, 'FaceColor', 'k', 'BarWidth', 1);
    set(MH2013_bar, 'FaceAlpha', 0.2);

    OA2020_bar = bar(aasm2020_event(1, :)*-2, 'FaceColor', 'r', 'BarWidth', 1);
    set(OA2020_bar, 'FaceAlpha', 0.2);
    CA2020_bar = bar(aasm2020_event(2, :)*-2, 'FaceColor', 'g', 'BarWidth', 1);
    set(CA2020_bar, 'FaceAlpha', 0.2);
    MA2020_bar = bar(aasm2020_event(3, :)*-2, 'FaceColor', 'm', 'BarWidth', 1);
    set(MA2020_bar, 'FaceAlpha', 0.2);
    OH2020_bar = bar(aasm2020_event(4, :)*-2, 'FaceColor', 'b', 'BarWidth', 1);
    set(OH2020_bar, 'FaceAlpha', 0.2);
    CH2020_bar = bar(aasm2020_event(5, :)*-2, 'FaceColor', 'c', 'BarWidth', 1);
    set(CH2020_bar, 'FaceAlpha', 0.2);
    MH2020_bar = bar(aasm2020_event(6, :)*-2, 'FaceColor', 'k', 'BarWidth', 1);
    set(MH2020_bar, 'FaceAlpha', 0.2);
    title("NPress Event");

    % Therm
    figure();
    plot(second_matrix(2, :)); hold on; grid on;
    plot(downsample(therm, 25));
    OA2013_bar = bar(aasm2013_event(1, :)*-1, 'FaceColor', 'r', 'BarWidth', 1);
    set(OA2013_bar, 'FaceAlpha', 0.2);
    CA2013_bar = bar(aasm2013_event(2, :)*-1, 'FaceColor', 'g', 'BarWidth', 1);
    set(CA2013_bar, 'FaceAlpha', 0.2);
    MA2013_bar = bar(aasm2013_event(3, :)*-1, 'FaceColor', 'm', 'BarWidth', 1);
    set(MA2013_bar, 'FaceAlpha', 0.2);
    OH2013_bar = bar(aasm2013_event(4, :)*-1, 'FaceColor', 'b', 'BarWidth', 1);
    set(OH2013_bar, 'FaceAlpha', 0.2);
    CH2013_bar = bar(aasm2013_event(5, :)*-1, 'FaceColor', 'c', 'BarWidth', 1);
    set(CH2013_bar, 'FaceAlpha', 0.2);
    MH2013_bar = bar(aasm2013_event(6, :)*-1, 'FaceColor', 'k', 'BarWidth', 1);
    set(MH2013_bar, 'FaceAlpha', 0.2);

    OA2020_bar = bar(aasm2020_event(1, :)*-2, 'FaceColor', 'r', 'BarWidth', 1);
    set(OA2020_bar, 'FaceAlpha', 0.2);
    CA2020_bar = bar(aasm2020_event(2, :)*-2, 'FaceColor', 'g', 'BarWidth', 1);
    set(CA2020_bar, 'FaceAlpha', 0.2);
    MA2020_bar = bar(aasm2020_event(3, :)*-2, 'FaceColor', 'm', 'BarWidth', 1);
    set(MA2020_bar, 'FaceAlpha', 0.2);
    OH2020_bar = bar(aasm2020_event(4, :)*-2, 'FaceColor', 'b', 'BarWidth', 1);
    set(OH2020_bar, 'FaceAlpha', 0.2);
    CH2020_bar = bar(aasm2020_event(5, :)*-2, 'FaceColor', 'c', 'BarWidth', 1);
    set(CH2020_bar, 'FaceAlpha', 0.2);
    MH2020_bar = bar(aasm2020_event(6, :)*-2, 'FaceColor', 'k', 'BarWidth', 1);
    set(MH2020_bar, 'FaceAlpha', 0.2);
    title("Threm Event");
    

    
    waitbar(i/filesNumber,h,strcat('Please wait...',num2str(round(i/filesNumber*100)),'%'))    
end
close(h);