clear;
close all;

inputDir = 'G:\共用雲端硬碟\Sleep center data\auto_detection\respiratory_detect\2022arousal_feature\';
goldenDir = 'G:\共用雲端硬碟\Sleep center data\auto_detection\sleep_scoring_AI\2022_Sleep_Scoring_AI\2022event\';
files = dir([inputDir '*.csv']);

%%
h = waitbar(0,'Please wait...');
filesNumber = length(files);

arousal_feature_prob = zeros(filesNumber, 63);
nonArousal_feature_prob = zeros(filesNumber, 63);

for i = 1 : filesNumber

    fprintf('file(%d/%d): %s is loaded.\n', i, filesNumber, files(i).name(1:end-4));

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

    %% 觀察特徵在arousal與非arousal的出現機率
    feature_prob = zeros(2, height(feature)); % row 1: arousal機率; row 2: nonArousal機率
    arousalSec = sum(arousal2020);
    nonArousalSec = length(find(arousal2020 == 0));
    for j = 1:height(feature)
        featureArousalSec = sum(feature(j, (arousal2020 == 1)));
        featureNonArousalSec = sum(feature(j, (arousal2020 == 0)));
        arousal_feature_prob(i, j) = featureArousalSec / arousalSec;
        nonArousal_feature_prob(i, j) = featureNonArousalSec / nonArousalSec;
    end

    waitbar(i/filesNumber,h,strcat('Please wait...',num2str(round(i/filesNumber*100)),'%'));  
end
close(h);