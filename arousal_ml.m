clear;
close all;

inputDir = 'G:\共用雲端硬碟\Sleep center data\auto_detection\respiratory_detect\2022arousal_feature_t4\';
goldenDir = 'G:\共用雲端硬碟\Sleep center data\auto_detection\sleep_scoring_AI\2022_Sleep_Scoring_AI\2022event\';
predictStageDir = 'G:\共用雲端硬碟\Sleep center data\auto_detection\sleep_scoring_AI\2022_Sleep_Scoring_AI\2022result\result_answer\';
files = dir([inputDir '*.csv']);

h = waitbar(0,'Please wait...');
filesNumber = length(files);
runningNumber = 0;

total_recall = [];
total_precision = [];

%% training 照AHI排序奇偶
dataX = [];
dataY = [];
for i = [39,2,18,19,28,27,21,1,33,31,6,15,12,38,41,8,30,29,5,14,24,7]
    runningNumber = runningNumber + 1;
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

    dataX = [dataX, feature];
    dataY = [dataY, arousal2020];

    waitbar(runningNumber/filesNumber,h,strcat('Please wait...',num2str(round(runningNumber/filesNumber*100)),'%'));  
end

decisionTree = fitctree(dataX', dataY', 'MaxNumSplits', 100);

%% testing
for i = [25,9,4,3,34,44,13,32,37,22,43,17,23,26,11,10,36,16,42,35,20,40]

    runningNumber = runningNumber + 1;

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

    arousal = predict(decisionTree, feature');
    arousal = arousal';

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
    total_recall(end+1) = recall;
    total_precision(end+1) = precision;
    disp("recall: " + string(recall) + " precision: " + string(precision));

    waitbar(runningNumber/filesNumber,h,strcat('Please wait...',num2str(round(runningNumber/filesNumber*100)),'%'));  
end

disp("total recall: " + string(mean(total_recall)) + " total precision: " + string(mean(total_precision)));
view(decisionTree, 'Mode', 'graph');

close(h);