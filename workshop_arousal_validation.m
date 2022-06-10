clear;
close all;

goldenDir = 'G:\共用雲端硬碟\Sleep center data\auto_detection\respiratory_detect\workshop_arousal\';
epoch = 742;

% load answer file
goldenFileName = 'expert001_2';

arousal2020 = zeros(1, epoch*30);
golden_file = join([goldenDir, goldenFileName, '.xlsx'], '');
[fileType, sheets] = xlsfinfo(golden_file);
[n, t, r] = xlsread(golden_file, string(sheets(1)));

for j = 1:height(r)
    if string(r(j, 4)) == 'ARO SPONT'
        arousal2020(round(n(j, 4)):round(n(j, 5))) = 1;
    end
end

% load test file
testFileName = 'expert001_1';

arousal = zeros(1, epoch*30);
golden_file = join([goldenDir, testFileName, '.xlsx'], '');
[fileType, sheets] = xlsfinfo(golden_file);
[n, t, r] = xlsread(golden_file, string(sheets(1)));

for j = 1:height(r)
    if string(r(j, 4)) == 'ARO SPONT'
        arousal(round(n(j, 4)):round(n(j, 5))) = 1;
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
disp("recall: " + string(recall) + " precision: " + string(precision));