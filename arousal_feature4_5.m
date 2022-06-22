clear;
close all;

workshop = 'G:\共用雲端硬碟\Sleep center data\auto_detection\respiratory_detect\workshop0606data\rawdata\';
InputDir = 'G:\共用雲端硬碟\Sleep center data\auto_detection\sleep_scoring_AI\2022_Sleep_Scoring_AI\2022data\';
OutputDir = 'G:\共用雲端硬碟\Sleep center data\auto_detection\respiratory_detect\2022arousal_feature_t4.5\';
workshop_output = 'G:\共用雲端硬碟\Sleep center data\auto_detection\respiratory_detect\workshop0606data\feature_t4\';
files = dir([InputDir '*.mat']);
t_variable = 4.5;

%%
filesNumber = length(files);

parfor i = 1 : filesNumber

    fprintf('file(%d/%d)\n', i, filesNumber);
    
    %% channels
    % 分析訊號 注意channels到底對不對
    data = load(join([InputDir, string(i), '.mat'], ''));
    
    fs = 200; %睡眠中心 sample rate 200 社科院 sample rate 512
    data = data.data;
    
    % c3m2、c4m1、f3m2、f4m1、o1m2、o2m1、e1m2、e2m1、emgr
    exg = data(1:9, :);
    epoch = floor((width(exg) / fs) / 30);
    
    %% 特徵提取

    % stft 2秒一次 重疊1秒
    window = fs * 2;
    overlap = 200;
    nfft = 2^nextpow2(window);
    for j = 1:9
        [s(j,:,:), f, t] = spectrogram(exg(j, :), window, overlap, nfft, fs);
    end
    % s為能量強度
    s = abs(s);
    s = (s ./ max(reshape(s, [], 1))) .*100;
    
    % band 計算每個能量帶 delta 0.3~4、theta 4~8、alpha 8~13、beta 13~22、gamma 22~35
    band = zeros(5, 9, epoch*30);
    for j = 1:9
        for k = 1:length(t)
            band(1, j, k) = mean(s(j, 2:11, k));
            band(2, j, k) = mean(s(j, 12:22, k));
            band(3, j, k) = mean(s(j, 22:35, k));
            band(4, j, k) = mean(s(j, 35:58, k));
            band(5, j, k) = mean(s(j, 58:91, k));
        end
    end

    s = [];

    % exg_amplitude 計算每2秒最大最小值相減 overlap 1秒
    exg_amplitude = zeros(9, epoch*30);
    % exg_energy
    exg_energy = zeros(9, epoch*30);
    for j = 1:height(exg)
        for k = 1:length(t)
            segment = exg(j, (k-1)*fs+1:(k-1)*fs+fs*2);
            exg_amplitude(j, k) = max(segment) - min(segment);
            exg_energy(j, k) = mean(abs(segment));
        end
    end

    %% 頻率變化偵測

    % 特徵1. 頻率突然變換
    band_change = zeros(5, 9, epoch*30);
    for b = 1:5
        for c = 1:9
            % 10秒為一組，檢查第11秒的值有無突然的上升
            for k = 11:epoch*30-40
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
                
                % ?倍標準差
                threshold = mean(segment) + std(segment)*t_variable;
                % 檢查第11秒
                if band(b, c, k) > threshold
                    % 往後檢查有幾秒持續大於threshold
                    % 若大於30秒則不算
                    count = 0;
                    for j = 1:40
                        if band(b, c, k+j) > threshold
                            count = count + 1;
                        else
                            break;
                        end
                    end
                    % 在矩陣中標記
                    if count <= 30
                        band_change(b, c, k:k+count) = 1;
                    end
                end
            end
        end
    end

    % 特徵2. 震幅突然變換
    amplitude_change = zeros(9, epoch*30);
    
    % 10秒為一組，檢查第11秒的值有無突然的上升
    for c = 1:9
        for k = 11:epoch*30-40
            segment = [];
            if k > 30 
                count = 0;
                % 抓30秒內無標記的10秒值
                for j = 1:30
                    if amplitude_change(c, k-j) == 0
                        segment(end+1) = exg_amplitude(c, k-j);
                        count = count + 1;
                    end
                    if count == 10 
                        break;
                    end
                end
            else
                segment = exg_amplitude(c, k-10:k-1);
            end
            
            % ?倍標準差
            threshold = mean(segment) + std(segment)*t_variable;
            
            % 檢查第11秒
            if exg_amplitude(c, k) > threshold
                % 往後檢查有幾秒持續大於threshold
                % 若大於20秒則不算
                count = 0;
                for j = 1:40
                    if exg_amplitude(c, k+j) > threshold
                        count = count + 1;
                    else
                        break;
                    end
                end
                % 在矩陣中標記
                if count <= 30
                    amplitude_change(c, k:k+count) = 1;
                end
            end
        end
    end

    % 特徵3. 能量突然變換
    energy_change = zeros(9, epoch*30);

    % 10秒為一組，檢查第11秒的值有無突然的上升
    for c = 1:9
        for k = 11:epoch*30-40
            segment = [];
            if k > 30 
                count = 0;
                % 抓30秒內無標記的10秒值
                for j = 1:30
                    if energy_change(c, k-j) == 0
                        segment(end+1) = exg_energy(c, k-j);
                        count = count + 1;
                    end
                    if count == 10 
                        break;
                    end
                end
            else
                segment = exg_energy(c, k-10:k-1);
            end
            
            % ?倍標準差
            threshold = mean(segment) + std(segment)*t_variable;
            
            % 檢查第11秒
            if exg_energy(c, k) > threshold
                % 往後檢查有幾秒持續大於threshold
                % 若大於30秒則不算
                count = 0;
                for j = 1:40
                    if exg_energy(c, k+j) > threshold
                        count = count + 1;
                    else
                        break;
                    end
                end
                % 在矩陣中標記
                if count <= 30
                    energy_change(c, k:k+count) = 1;
                end
            end
        end
    end

    % 匯出特徵
    final_output = [...
        reshape(band_change(1, :, :), 9, []);...
        reshape(band_change(2, :, :), 9, []);...
        reshape(band_change(3, :, :), 9, []);...
        reshape(band_change(4, :, :), 9, []);...
        reshape(band_change(5, :, :), 9, []);...
        amplitude_change;...
        energy_change;...
    ];
    csvwrite(join([OutputDir, string(i), '.csv'], ''), final_output);

end