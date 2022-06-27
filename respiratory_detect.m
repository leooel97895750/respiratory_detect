clear;
close all;

inputDir = 'G:\共用雲端硬碟\Sleep center data\auto_detection\respiratory_detect\2020respiratory_feature\';
goldenDir = 'G:\共用雲端硬碟\Sleep center data\auto_detection\sleep_scoring_AI\2022_Sleep_Scoring_AI\2022event\';

total_recall = [];
total_precision = [];

% AASM2020新規則
apnea_all = [38,80,10,36,30,112,64,43,51,23,118,91,109,88,49,35,94,29,107,116,12,26,8,92,41,120,70,11,7,14,5,93,46,42,101,24,20,54,68,40];
hypopnea_all = [62,24,55,32,108,42,100,75,20,33,73,46,54,37,31,67,117,49,22,111,110,89,99,6,50,23,64,15,97,84,87,41,5,26,106,71,82,11,17,94,38,8,77,14,85,83,116,79,119,68,86,118,57,90,101,29,107,80,10,88,30,36,109,51,112,7,91,16,35,120,92,93,70,95,74];

apnea_allx = [38,10,36,30,112,64,43,51,23,118,109,88,49,35,94,29,107,116,12,26,41,120,11,14,5,46,42,101,24,20,54,68,40];

for i = hypopnea_all

    feature = load(join([inputDir, string(i), '.csv'], ''));

    %% 載入標準答案(以睡眠中心event格式)
    % OA、CA、MA、OH、CH、MH、SpO2、SpO2_Artifact、Arousal_res、Arousal_limb、Arousal_spont、Arousal_plm
    golden_event = zeros(12, width(feature));
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
    golden_event = golden_event(:, 1:width(feature));

    %% phase 1 NPress Therm 全局threshold

    npress = feature(1, :);
    therm = feature(2, :);
    % 排序
    npress_sort = sort(npress, 'descend');
    therm_sort = sort(therm, 'descend');
    % 微分求斜率
    npress_diff = diff(npress_sort);
    therm_diff = diff(therm_sort);
    % 分成 20% 60% 20% 取60%中斜率前10%小的區段取平均當作全局threshold
    [n60, n60i] = sort(abs(npress_diff(floor(length(npress_diff)*0.2) : floor(length(npress_diff)*0.8))));
    [t60, t60i] = sort(abs(therm_diff(floor(length(therm_diff)*0.2) : floor(length(therm_diff)*0.8))));
    npress_threshold = mean(npress_sort(n60i(1 : floor(length(n60)*0.2)) + floor(length(npress_diff)*0.2)));
    therm_threshold = mean(therm_sort(t60i(1 : floor(length(t60)*0.2)) + floor(length(therm_diff)*0.2)));

    %% phase 2 window

    % therm異常、npress異常
    breath_matrix = zeros(2, length(therm));
    t_plot = zeros(1, length(therm));
    n_plot = zeros(1, length(npress));
    % therm
    window_size = 60;
    for j = window_size:length(therm)
        window = sort(therm(j-window_size+1:j-1));
        window = window(1:round(length(window)*0.9));
        threshold = mean(window(window >= mean(window)));
        t_plot(j) = threshold;
        % 檢查此點j有無小於threshold，有則標記成異常，並寫入下降%數
        if (therm(j) < threshold) && (therm(j) < therm_threshold)
            breath_matrix(1, j) = round(((threshold - therm(j)) / threshold)*100);
        end
    end
    % npress
    for j = window_size:length(npress)
        window = sort(npress(j-window_size+1:j-1));
        window = window(1:round(length(window)*0.9));
        threshold = mean(window(window >= mean(window)));
        n_plot(j) = threshold;
        % 檢查此點j有無小於threshold，有則標記成異常，並寫入下降%數
        if (npress(j) < threshold) && (npress(j) < npress_threshold)
            breath_matrix(2, j) = round(((threshold - npress(j)) / threshold)*100);
        end
    end

    %% phase 3 Apnea

    % apnea hypopnea spo2
    event_matrix = zeros(3, length(therm));
    [start, sp, ep] = deal(0); 
    for j = 1:length(therm)
        % 下降超過80
        if (breath_matrix(1, j) >= 80) && (start == 0)
            start = 1;
            sp = j;
        elseif (breath_matrix(1, j) < 80) && (start == 1)
            start = 0;
            ep = j - 1;
            % 長度檢查
            if (ep - sp) > 10
                event_matrix(1, sp:ep) = 1;
            end
        end
    end

    %% phase 4 SpO2

    spo2 = feature(5, :);

    [count, start, range] = deal(0);
    previous = spo2(1);
    for j = 1:length(spo2)
        if (spo2(j) < previous) && (start == 0)
            [count, start, range] = deal(1);
        elseif (spo2(j) == previous) && (start == 1)
            range = range + 1;
        elseif (spo2(j) < previous) && (start == 1)
            range = range + 1;
            count = count + 1;
        else
            % 下降3% 且無artifact(<10)
            if (count >= 3) && (sum(spo2(j-range:j-1) < 10) == 0)
                event_matrix(3, j-range:j-1) = count;
            end
            start = 0;
            count = 0;
        end
        previous = spo2(j);
    end

    %% phase 5 hypopnea

    [start, sp, ep] = deal(0); 
    for j = 1:length(npress)
        % 下降超過40
        if (breath_matrix(2, j) >= 40) && (start == 0)
            start = 1;
            sp = j;
        elseif (breath_matrix(2, j) < 40) && (start == 1)
            start = 0;
            ep = j - 1;
            % 長度檢查
            if (ep - sp) > 10
                % 範圍內apnea檢查
                if sum(event_matrix(1, sp:ep)) == 0
                    event_matrix(2, sp:ep) = 1;
                end
            end
        end
    end

    %% 畫圖

    figure(i);
    hold on; grid on;
    plot(npress);
    plot(therm);
    apnea2020 = golden_event(1, :) | golden_event(2, :) | golden_event(3, :);
    apnea_bar = bar(apnea2020, 'FaceColor', 'r', 'BarWidth', 1);
    set(apnea_bar, 'FaceAlpha', 0.5);
    hypopnea2020 = golden_event(4, :) | golden_event(5, :) | golden_event(6, :);
    hypopnea_bar = bar(hypopnea2020, 'FaceColor', 'b', 'BarWidth', 1);
    set(hypopnea_bar, 'FaceAlpha', 0.5);
    spo2_bar = bar(golden_event(7, :)*-0.5, 'FaceColor', 'k', 'BarWidth', 1);
    set(spo2_bar, 'FaceAlpha', 0.5);
    arousal2020 = golden_event(9, :) | golden_event(10, :) | golden_event(11, :) | golden_event(12, :);
    arousal_bar = bar(arousal2020*0.5, 'FaceColor', 'g', 'BarWidth', 1);
    set(arousal_bar, 'FaceAlpha', 0.5);
    ad_bar = bar((event_matrix(1, :)~=0)*-1, 'FaceColor', 'r', 'BarWidth', 1);
    set(ad_bar, 'FaceAlpha', 0.5);
    hd_bar = bar((event_matrix(2, :)~=0)*-1, 'FaceColor', 'b', 'BarWidth', 1);
    set(hd_bar, 'FaceAlpha', 0.5);

    %% 驗證

    % 取出想要驗證的陣列
    my_ans = event_matrix(2, :) ~= 0;
    golden = hypopnea2020;
    [tp, fn, fp, cont, es, ee] = deal(0);
    for j = 1:length(golden)
        if (golden(j) == 1) && (cont == 0)
            es = j;
            cont = 1;
        elseif (golden(j) == 0) && (cont == 1)
            ee = j - 1;
            cont = 0;
            if sum(my_ans(es:ee)) > 0
                tp = tp + 1;
            else
                fn = fn + 1;
            end
        end
    end
    for j = 1:length(my_ans)
        if (my_ans(j) == 1) && (cont == 0)
            es = j;
            cont = 1;
        elseif (my_ans(j) == 0) && (cont == 1)
            ee = j - 1;
            cont = 0;
            if sum(golden(es:ee)) == 0
                fp = fp + 1;
            end
        end
    end
    recall = tp/(tp+fn);
    precision = tp/(tp+fp);
    % 無事件則不納入統計
    if ((tp+fn) ~= 0) && ((tp+fp) ~= 0)
        total_recall(end+1) = recall;
        total_precision(end+1) = precision;
        fprintf("file %d   \trecall: %2.2f\tprecision: %2.2f\n", i, round(recall, 2), round(precision, 2));
    end
end

disp("total recall: " + string(mean(total_recall)) + " total precision: " + string(mean(total_precision)));