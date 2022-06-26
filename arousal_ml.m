clear
close all

% workshop = 'G:\共用雲端硬碟\Sleep center data\auto_detection\respiratory_detect\workshop0606data\feature_t4\';
inputDir = 'G:\共用雲端硬碟\Sleep center data\auto_detection\respiratory_detect\2022arousal_feature_t4\';
goldenDir = 'G:\共用雲端硬碟\Sleep center data\auto_detection\sleep_scoring_AI\2022_Sleep_Scoring_AI\2022event\';
predictStageDir = 'G:\共用雲端硬碟\Sleep center data\auto_detection\sleep_scoring_AI\2022_Sleep_Scoring_AI\2022result\result_answer\';
workshop_golden = 'G:\共用雲端硬碟\Sleep center data\auto_detection\respiratory_detect\workshop0606data\';
workshop_stage = 'G:\共用雲端硬碟\Sleep center data\auto_detection\respiratory_detect\workshop0606data\stage\';
outputDir = 'G:\共用雲端硬碟\Sleep center data\auto_detection\sleep_scoring_AI\2022_Sleep_Scoring_AI\2022arousal\';

runningNumber = 0;

total_human_ari = [];
total_auto_ari = [];
total_diff = [];
total_recall = [];
total_precision = [];

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

%% training 照AHI排序奇偶
dataX = [];
dataY = [];
for i = yAHI_all
    runningNumber = runningNumber + 1;
    % 載入feature
    feature = load(join([inputDir, string(i), '.csv'], ''));
    epoch = floor(length(feature) / 30);

    % 載入標準答案 (以睡眠中心event格式)
    % OA、CA、MA、OH、CH、MH、SpO2、SpO2_Artifact、Arousal_res、Arousal_limb、Arousal_spont、Arousal_plm
    golden_event = zeros(12, epoch*30);
    golden_file = join([goldenDir, string(i), '.xlsx'], '');
    [fileType, sheets] = xlsfinfo(golden_file);
    % eventid、second、duration、para1、para2、para3、man_scored
    golden_data = xlsread(golden_file, string(sheets(1)));
    
    for j = 1:height(golden_data)
        % Arousal_res
        if golden_data(j, 1) == 7
            golden_event(9, round(golden_data(j, 2)) : round(golden_data(j, 2) + golden_data(j, 3))) = 1;
        % Arousal_limb
        elseif golden_data(j, 1) == 8
            golden_event(10, round(golden_data(j, 2)) : round(golden_data(j, 2) + golden_data(j, 3))) = 1;
        % Arousal_spont
        elseif golden_data(j, 1) == 9
            golden_event(11, round(golden_data(j, 2)) : round(golden_data(j, 2) + golden_data(j, 3))) = 1;
        % Arousal_plm
        elseif golden_data(j, 1) == 10
            golden_event(12, round(golden_data(j, 2)) : round(golden_data(j, 2) + golden_data(j, 3))) = 1;
        end
    end
    golden_event = golden_event(:, 1:epoch*30);
    arousal2020 = golden_event(9, :) | golden_event(10, :) | golden_event(11, :) | golden_event(12, :);

    dataX = [dataX, feature];
    dataY = [dataY, arousal2020];

end

decisionTree = fitctree(dataX', dataY', 'MaxNumSplits', 30);

%% testing
for i = xAHI_all

    runningNumber = runningNumber + 1;

    % 載入feature
    feature = load(join([inputDir, string(i), '.csv'], ''));
    epoch = floor(length(feature) / 30);

    % 載入標準答案 (以睡眠中心event格式)
    % OA、CA、MA、OH、CH、MH、SpO2、SpO2_Artifact、Arousal_res、Arousal_limb、Arousal_spont、Arousal_plm
    golden_event = zeros(12, epoch*30);
    golden_file = join([goldenDir, string(i), '.xlsx'], '');
    [fileType, sheets] = xlsfinfo(golden_file);
    % eventid、second、duration、para1、para2、para3、man_scored
    golden_data = xlsread(golden_file, string(sheets(1)));
    
    for j = 1:height(golden_data)
        % Arousal_res
        if golden_data(j, 1) == 7
            golden_event(9, round(golden_data(j, 2)) : round(golden_data(j, 2) + golden_data(j, 3))) = 1;
        % Arousal_limb
        elseif golden_data(j, 1) == 8
            golden_event(10, round(golden_data(j, 2)) : round(golden_data(j, 2) + golden_data(j, 3))) = 1;
        % Arousal_spont
        elseif golden_data(j, 1) == 9
            golden_event(11, round(golden_data(j, 2)) : round(golden_data(j, 2) + golden_data(j, 3))) = 1;
        % Arousal_plm
        elseif golden_data(j, 1) == 10
            golden_event(12, round(golden_data(j, 2)) : round(golden_data(j, 2) + golden_data(j, 3))) = 1;
        end
    end
    golden_event = golden_event(:, 1:epoch*30);
    arousal2020 = golden_event(9, :) | golden_event(10, :) | golden_event(11, :) | golden_event(12, :);
%     goldenFileName = 'ncku_golden_event';
%     
%     arousal2020 = zeros(1, epoch*30);
%     golden_file = join([workshop_golden, goldenFileName, '.xlsx'], '');
%     [fileType, sheets] = xlsfinfo(golden_file);
%     [n, t, r] = xlsread(golden_file, string(sheets(1)));
%     
%     for j = 1:height(r)
%         if string(r(j, 1)) == 'ARO SPONT'
%             arousal2020(round(n(j, 1)):(round(n(j, 1))+round(n(j, 2)))) = 1;
%         end
%     end

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
%     stage_file = join([workshop_stage, 'stage.dat'], '');
    stage_file = join([predictStageDir, string(i) '.dat.csv'], '');
    stage = load(stage_file);
    human_stage = stage(:, 1);
    pred_stage = stage(:, 4);
%     pred_stage = stage;
    for j = 1:length(pred_stage)
        if pred_stage(j) == 0 || pred_stage(j) == 3
            if (30+(j-1)*30) < length(arousal)
                arousal(1+(j-1)*30:30+(j-1)*30) = 0;
            end
        end
    end

    % 計算標準 arousal index
    spoint = 0;
    epoint = 0;
    start = 0;
    arousal2020_count = 0;
    for j = 1:length(arousal2020)
        if (arousal2020(j) == 1) && (start == 0)
            spoint = j;
            start = 1;
        elseif (arousal2020(j) == 0) && (start == 1)
            epoint = j - 1;
            start = 0;
            arousal2020_count = arousal2020_count + 1;
%             if(human_stage(ceil(spoint/30)) == 0)
%                 arousal2020(spoint:epoint) = 0;
%                 arousal2020_count = arousal2020_count - 1;
%             end
        end
    end
    human_ari = arousal2020_count / (sum(human_stage ~= 0) / 120);

    % 計算預測 arousal index
    spoint = 0;
    epoint = 0;
    start = 0;
    arousal_count = 0;
    for j = 1:length(arousal)
        if (arousal(j) == 1) && (start == 0)
            spoint = j;
            start = 1;
        elseif (arousal(j) == 0) && (start == 1)
            epoint = j - 1;
            start = 0;
            arousal_count = arousal_count + 1;
            if(human_stage(floor(spoint/30)) == 0)
                arousal(spoint:epoint) = 0;
                arousal_count = arousal_count - 1;
            end
        end
    end
    auto_ari = arousal_count / (sum(pred_stage ~= 0) / 120);

    total_human_ari(end+1) = human_ari;
    total_auto_ari(end+1) = auto_ari;
    total_diff(end+1) = abs(human_ari - auto_ari);
    disp("標準ArI: " + human_ari + " 偵測ArI: " + auto_ari + " 差異: " + total_diff(end));

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
    disp("file " + string(i) + "    recall: " + string(recall) + " precision: " + string(precision));

    csvwrite(join([outputDir, string(i), '.csv'], ''), arousal);

end

ari_diff = mean(abs(total_human_ari - total_auto_ari));
disp("total recall: " + string(mean(total_recall)) + " total precision: " + string(mean(total_precision)) + " ari diff: " + string(ari_diff));
% view(decisionTree, 'Mode', 'graph');
