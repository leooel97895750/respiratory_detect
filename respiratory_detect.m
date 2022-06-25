clear;
close all;

inputDir = 'G:\共用雲端硬碟\Sleep center data\auto_detection\respiratory_detect\2020respiratory_feature\';
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

for i = [1,93]

    fprintf('file(%d/%d)\n', i, 60);
    feature = load(join([inputDir, string(i), '.csv'], ''));

    %% 載入標準答案(以睡眠中心event格式)
    % OA、CA、MA、OH、CH、MH、SpO2、SpO2_Artifact、Arousal_res、Arousal_limb、Arousal_spont、Arousal_plm
    golden_event = zeros(12, width(feature));
    golden_file = join([goldenDir, string(i), '.xlsx'], '');
    [fileType, sheets] = xlsfinfo(golden_file);
    % eventid、second、duration、para1、para2、para3、man_scored
    golden_data = xlsread(golden_file, string(sheets(1)));    
    for j = 1:height(golden_data)       
        if golden_data(j, 1) == 1 && golden_data(j, 7) == 1 % CA
            golden_event(2, round(golden_data(j, 2)) : round(golden_data(j, 2) + golden_data(j, 3))) = 1;      
        elseif golden_data(j, 1) == 2 && golden_data(j, 7) == 1 % OA
            golden_event(1, round(golden_data(j, 2)) : round(golden_data(j, 2) + golden_data(j, 3))) = 1;       
        elseif golden_data(j, 1) == 3 && golden_data(j, 7) == 1 % MA
            golden_event(3, round(golden_data(j, 2)) : round(golden_data(j, 2) + golden_data(j, 3))) = 1;        
        elseif golden_data(j, 1) == 29 && golden_data(j, 7) == 1 % OH
            golden_event(4, round(golden_data(j, 2)) : round(golden_data(j, 2) + golden_data(j, 3))) = 1;
        elseif golden_data(j, 1) == 30 && golden_data(j, 7) == 1 % CH
            golden_event(5, round(golden_data(j, 2)) : round(golden_data(j, 2) + golden_data(j, 3))) = 1;        
        elseif golden_data(j, 1) == 31 && golden_data(j, 7) == 1 % MH
            golden_event(6, round(golden_data(j, 2)) : round(golden_data(j, 2) + golden_data(j, 3))) = 1;        
        elseif golden_data(j, 1) == 4 && golden_data(j, 7) == 1 % SpO2
            golden_event(7, round(golden_data(j, 2)) : round(golden_data(j, 2) + golden_data(j, 3))) = 1;        
        elseif golden_data(j, 1) == 7 && golden_data(j, 7) == 1 % Arousal_res
            golden_event(9, round(golden_data(j, 2)) : round(golden_data(j, 2) + golden_data(j, 3))) = 1;        
        elseif golden_data(j, 1) == 8 && golden_data(j, 7) == 1 % Arousal_limb
            golden_event(10, round(golden_data(j, 2)) : round(golden_data(j, 2) + golden_data(j, 3))) = 1;
        elseif golden_data(j, 1) == 9 && golden_data(j, 7) == 1 % Arousal_spont
            golden_event(11, round(golden_data(j, 2)) : round(golden_data(j, 2) + golden_data(j, 3))) = 1;
        elseif golden_data(j, 1) == 10 && golden_data(j, 7) == 1 % Arousal_plm
            golden_event(12, round(golden_data(j, 2)) : round(golden_data(j, 2) + golden_data(j, 3))) = 1;
        end
    end
    golden_event = golden_event(:, 1:width(feature));

    %% phase 1 匡列異常呼吸區域(NPress、Therm)

    npress = feature(1, :);
    therm = feature(2, :);
    % 排序
    npress_sort = sort(npress, 'descend');
    therm_sort = sort(therm, 'descend');
    % 微分求斜率
    npress_diff = diff(npress_sort);
    therm_diff = diff(therm_sort);
    % 分成 10% 80% 10% 取80%中斜率前10%小的區段取平均當作threshold
    [n80, n80i] = sort(abs(npress_diff(floor(length(npress_diff)/10) : floor((length(npress_diff)/10)*9))));
    [t80, t80i] = sort(abs(therm_diff(floor(length(therm_diff)/10) : floor((length(therm_diff)/10)*9))));
    npress_threshold = mean(npress_sort(n80i(1 : floor(length(n80)/10)) + floor(length(npress_diff)/10)));
    therm_threshold = mean(therm_sort(t80i(1 : floor(length(t80)/10)) + floor(length(therm_diff)/10)));
    % 10秒window中都沒有超過threshold則匡列異常(npress、therm 一起檢查)
    breath_matrix = zeros(2, length(npress));
    [nstart, ns, ne] = deal(0);
    [tstart, ts, te] = deal(0);
    for j = 1:length(npress)
        % npress
        if (npress(j) < npress_threshold) && (nstart == 0)
            nstart = 1;
            ns = j;
        elseif (npress(j) >= npress_threshold) && (nstart == 1)
            nstart = 0;
            ne = j - 1;
            if (ne - ns) > 10
                breath_matrix(1, ns:ne) = 1;
            end
        end
        % therm
        if (therm(j) < therm_threshold) && (tstart == 0)
            tstart = 1;
            ts = j;
        elseif (therm(j) >= therm_threshold) && (tstart == 1)
            tstart = 0;
            te = j - 1;
            if (te - ts) > 10
                breath_matrix(2, ts:te) = 1;
            end
        end
    end


    % 排序後npress、therm圖
    figure(i);
    hold on; grid on;
    plot(npress);
    plot(therm);
    apnea2020 = golden_event(1, :) | golden_event(2, :) | golden_event(3, :);
    npress_bar = bar(apnea2020, 'FaceColor', 'r', 'BarWidth', 1);
    set(npress_bar, 'FaceAlpha', 0.5);
    hypopnea2020 = golden_event(4, :) | golden_event(5, :) | golden_event(6, :);
    therm_bar = bar(hypopnea2020, 'FaceColor', 'b', 'BarWidth', 1);
    set(therm_bar, 'FaceAlpha', 0.5);

end