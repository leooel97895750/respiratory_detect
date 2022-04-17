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
    stage = readtable('.\2022data\stage.csv');
    stage = stage.Var1;
    aasm2020 = readtable('.\2022data\20191018_徐O文_2020aasm.csv');
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
    for j = 1:height(exg)
        [s(j,:,:), f, t] = spectrogram(exg(j,:), window, overlap, nfft, fs);
    end
    % s為能量強度
    s = abs(s);
    s = (s ./ max(reshape(s, [], 1))) .*100;
    
    % band
    % 計算每個能量帶
    % delta 0.5~4、theta 4~8、alpha 8~13、lbeta 13~28、gamma 28~50
    band = zeros(6, 9, epoch*30);
    for j = 1:height(exg)
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
    band_change = zeros(5, 9, epoch*30);
    for b = 1:5
        tplot = zeros(9, epoch*30);
        for c = 1:9
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
                count = 0;
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
            % 畫圖 5 * 9 (太多了)
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

    %% 驗證震幅
    % 震幅
    figure();
    ax(1) = subplot(3,1,1);
    hold on; grid on;
    plot(exg_amplitude(1, :), 'DisplayName', 'c3m2');
    plot(exg_amplitude(2, :), 'DisplayName', 'c4m2');
    plot(exg_amplitude(3, :), 'DisplayName', 'f3m2');
    plot(exg_amplitude(4, :), 'DisplayName', 'f4m1');
    plot(exg_amplitude(5, :), 'DisplayName', 'o1m2');
    plot(exg_amplitude(6, :), 'DisplayName', 'o2m1');
%     plot(exg_amplitude(7, :), 'DisplayName', 'e1m2');
%     plot(exg_amplitude(8, :), 'DisplayName', 'e2m1');
%     plot(exg_amplitude(9, :), 'DisplayName', 'emgr');
    arousal_bar = bar(arousal2020*1000, 'FaceColor', 'r', 'BarWidth', 1);
    set(arousal_bar, 'FaceAlpha', 0.2);
    axis tight;
    ylim([0 1000]);

    % 頻率
    ax(2) = subplot(3,1,2);
    hold on; grid on;
    plot(reshape(band(1, 1, :), 1, []), 'DisplayName', 'delta');
    plot(reshape(band(2, 1, :), 1, []), 'DisplayName', 'theta');
    plot(reshape(band(3, 1, :), 1, []), 'DisplayName', 'alpha');
    plot(reshape(band(4, 1, :), 1, []), 'DisplayName', 'beta');
    plot(reshape(band(5, 1, :), 1, []), 'DisplayName', 'gamma');
    arousal_bar = bar(arousal2020*50, 'FaceColor', 'r', 'BarWidth', 1);
    set(arousal_bar, 'FaceAlpha', 0.2);
    axis tight;
    ylim([0 3]);

    % hypnogram
    ax(3) = subplot(3,1,3);
    hold on; grid on;
    bigstage = [];
    for i=1:length(stage)
        for j=1:30
            bigstage(end+1) = stage(i);
        end
    end
    W=bigstage==0;
    R=bigstage==-1;
    bar(R,'FaceColor','#A2142F','BarWidth',1)
    N1=bigstage==1;
    bar(N1*-1,'FaceColor','#EDB120','BarWidth',1)
    N2=bigstage==2;
    bar(N2*-2,'FaceColor','#77AC30','BarWidth',1)
    N3=bigstage==3;
    bar(N3*-3,'FaceColor','#0072BD','BarWidth',1)
    axis tight;
    ylim([-3 1]);
    yticklabels({'N3','N2','N1','W','R'});
    
    linkaxes(ax, 'x');

    %% 畫各個channels與bands的預測圖
    for c = 1:9
        figure();
        hold on; grid on;
        % 標準答案 紅
        arousal_bar = bar(arousal2020*6, 'FaceColor', 'r', 'BarWidth', 1);
        set(arousal_bar, 'FaceAlpha', 0.2);
        % 訊號異常 黑
        abnormal_bar = bar(exg_abnormal*6, 'FaceColor', 'k', 'BarWidth', 1);
        set(abnormal_bar, 'FaceAlpha', 0.2);
        % beta 綠
        beta_bar = bar(reshape(band_change(4, c, :)*5, 1, []), 'FaceColor', 'g', 'BarWidth', 1, 'DisplayName', 'beta');
        set(beta_bar, 'FaceAlpha', 0.2);
        % alpha 黃
        alpha_bar = bar(reshape(band_change(3, c, :)*4, 1, []), 'FaceColor', '#EDB120', 'BarWidth', 1, 'DisplayName', 'alpha');
        set(alpha_bar, 'FaceAlpha', 0.2);
        % gamma 紫
        gamma_bar = bar(reshape(band_change(5, c, :)*3, 1, []), 'FaceColor', 'm', 'BarWidth', 1, 'DisplayName', 'gamma');
        set(gamma_bar, 'FaceAlpha', 0.2);
        % theta 橘
        theta_bar = bar(reshape(band_change(2, c, :)*2, 1, []), 'FaceColor', '#D95319', 'BarWidth', 1, 'DisplayName', 'theta');
        set(theta_bar, 'FaceAlpha', 0.2);
        % delta 藍
        delta_bar = bar(reshape(band_change(1, c, :)*1, 1, []), 'FaceColor', 'b', 'BarWidth', 1, 'DisplayName', 'delta');
        set(delta_bar, 'FaceAlpha', 0.2);

        axis tight;
        ylim([0 30]);
        
        title("channels: " + string(c));
    end

    waitbar(i/filesNumber,h,strcat('Please wait...',num2str(round(i/filesNumber*100)),'%'))    
end
close(h);