clear;
close all;

inputDir = 'G:\共用雲端硬碟\Sleep center data\auto_detection\respiratory_detect\2022arousal_feature_t4\';
goldenDir = 'G:\共用雲端硬碟\Sleep center data\auto_detection\sleep_scoring_AI\2022_Sleep_Scoring_AI\2022event\';
predictStageDir = 'G:\共用雲端硬碟\Sleep center data\auto_detection\sleep_scoring_AI\2022_Sleep_Scoring_AI\2022result\result_answer\';
files = dir([inputDir '*.csv']);

%%
h = waitbar(0,'Please wait...');
filesNumber = length(files);

arousal_feature_prob = zeros(filesNumber, 63);
nonArousal_feature_prob = zeros(filesNumber, 63);

arousal_feature_compose = containers.Map();

recall_list = [];
precision_list = [];

arousal_count = 0;
arousal_feature_count = zeros(1, 63);

AHI5 = [60,52,53,47,48,66,9,19,3,34,58,63,27,61,44];
AHI5_30 = [59,62,56,55,33,37,31,22,6,43,15,50,12,23];
AHI30 = [26,41,11,8,10,30,36,29,51,16,5,42,14,24,20];

for i = 1 : filesNumber

    %fprintf('file(%d/%d): %s is loaded.\n', i, filesNumber, files(i).name(1:end-4));
%     if ismember(str2num(files(i).name(1:end-4)), [21,33,22,25,28,31,43,15,2])
%         continue;
%     end

    % 載入feature
    feature = readtable([inputDir files(i).name]);
    feature = feature{:, :};
    epoch = floor(length(feature) / 30);

    % 載入標準答案 (以睡眠中心event格式)
    % OA、CA、MA、OH、CH、MH、SpO2、SpO2_Artifact、Arousal_res、Arousal_limb、Arousal_spont、Arousal_plm
    golden_event = zeros(12, epoch*30);
    golden_file = [goldenDir, files(i).name(1:end-4), '.xlsx'];
    [fileType, sheets] = xlsfinfo(golden_file);
    % eventid、second、duration、para1、para2、para3、man_scored
    golden_data = xlsread(golden_file, string(sheets(1)));
    
    for j = 1:height(golden_data)
        % Arousal_res
        if golden_data(j, 1) == 7 && golden_data(j, 7) == 1
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
    arousal2020 = golden_event(9, :) | golden_event(10, :) | golden_event(11, :) | golden_event(12, :);

    %% 觀察特徵在arousal與非arousal的出現比例

    %% 觀察特徵在arousal時的組合


    %% 觀察特徵在arousal時出現的機率


    %% Arousal偵測 Ver.3 可能要結合stage判讀，可以剃除wake跟n3的特徵變化
    arousal = zeros(2, epoch*30-1);
    for j = 2:epoch*30-1
        % abormal處理，有左右的feature選用能量較小的一邊
        if feature(55, j) > feature(56, j)
            feature_c3c4 = feature([2,11,20,29,38,47,56], j);
        else
            feature_c3c4 = feature([1,10,19,28,37,46,55], j);
        end
        if feature(57, j) > feature(58, j)
            feature_f3f4 = feature([4,13,22,31,40,49,58], j);
        else
            feature_f3f4 = feature([3,12,21,30,39,48,57], j);
        end
        o1o2 = '';
        if feature(59, j) > feature(60, j)
            feature_o1o2 = feature([6,15,24,33,42,51,60], j);
        else
            feature_o1o2 = feature([5,14,23,32,41,50,59], j);
        end
        e1e2 = '';
        if feature(61, j) > feature(62, j)
            feature_e1e2 = feature([8,17,26,35,44,53,62], j);
        else
            feature_e1e2 = feature([7,16,25,34,43,52,61], j);
        end
        feature_emg = feature([9,18,27,36,45,54,63], j);
     
        % 要先弄1秒，後處理洗掉1秒的，再模糊成3秒
        % arousal中出現機率高的特徵
        %3,4,9,18,27,30,36,39,45,48,49,54,57,58,63
        if feature(3, j) || feature(4, j) || feature(9, j) || feature(18, j) || feature(27, j) || feature(30, j) || feature(36, j)...
            || feature(39, j) || feature(45, j) || feature(48, j) || feature(49, j) || feature(54, j) || feature(57, j) || feature(58, j) || feature(63, j)
            arousal(j) = 1;
        end

        % 腦波完全沒變化
        if (sum(feature(1:6, j)) == 0) && (sum(feature(19:24, j)) == 0) && (sum(feature(28:33, j)) == 0) && (sum(feature(37:42, j)) == 0) && (sum(feature(55:60, j)) == 0)
            arousal(j) = 0;
        end

        % 肌動完全沒變化
        if (sum(feature(9, j)) == 0) && (sum(feature(27, j)) == 0) && (sum(feature(36, j)) == 0) && (sum(feature(45, j)) == 0) && (sum(feature(54, j)) == 0) && (sum(feature(63, j)) == 0)
            arousal(j) = 0;
        end

    end

    % 後處理 先向後模糊1秒再刪除小於2秒
    start = 0;
    for j = 1:length(arousal)-1
        if arousal(j) == 1 && start == 0
            start = 1;
        elseif arousal(j) == 0 && start == 1
            start = 0;
            arousal(j) = 1;
        end
    end
    spoint = 0;
    epoint = 0;
    start = 0;
    for j = 1:length(arousal)
        if arousal(j) == 1 && start == 0
            start = 1;
            spoint = j;
        elseif arousal(j) == 0 && start == 1
            start = 0;
            epoint = j - 1;
            % 刪除小於2秒的預測
            if (epoint - spoint) < 2
                arousal(spoint:epoint) = 0;
            end
        end
    end


    % 用預測的stage做後處理
    stage_file = [predictStageDir, files(i).name(1:end-4), '.dat.csv'];
    stage = load(stage_file);
    pred_stage = stage(:, 4);
    for j = 1:length(pred_stage)
        if pred_stage(j) == 0 || pred_stage(j) == 3
            if (30+(j-1)*30) < length(arousal)
                arousal(1+(j-1)*30:30+(j-1)*30) = 0;
            end
        end
    end
    

    % 畫圖
%     figure();
%     grid on; hold on;
%     arousal2020_bar = bar(arousal2020, 'FaceColor', 'r', 'BarWidth', 1);
%     set(arousal2020_bar, 'FaceAlpha', 0.2);
%     arousal_bar = bar(arousal*-1, 'FaceColor', 'b', 'BarWidth', 1);
%     set(arousal_bar, 'FaceAlpha', 0.2);

    % 計算 recall precision
    tp = 0;
    fn = 0;
    fp = 0;
    
    cont = 0;
    es = 0;
    ee = 0;
    for j = 1:length(arousal2020)
        if (arousal2020(j) == 1) && (cont == 0)
            es = j;
            cont = 1;
        elseif (arousal2020(j) == 0) && (cont == 1)
            ee = j - 1;
            cont = 0;
            if sum(arousal(es:ee)) > 0
                tp = tp + 1;
            else
                fn = fn + 1;
            end
        end
    end
    for j = 1:length(arousal)
        if (arousal(j) == 1) && (cont == 0)
            es = j;
            cont = 1;
        elseif (arousal(j) == 0) && (cont == 1)
            ee = j - 1;
            cont = 0;
            if sum(arousal2020(es:ee)) == 0
                fp = fp + 1;
            end
        end
    end

    recall = tp/(tp+fn);
    precision = tp/(tp+fp);
    recall_list(end+1) = recall;
    precision_list(end+1) = precision;
    disp(files(i).name + " recall: " + string(recall) + " precision: " + string(precision));

    waitbar(i/filesNumber,h,strcat('Please wait...',num2str(round(i/filesNumber*100)),'%'));  
end

disp("average recall: " + string(mean(recall_list)));
disp("average precision: " + string(mean(precision_list)));



close(h);