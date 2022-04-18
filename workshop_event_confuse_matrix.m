close all;
clear;

xlsFile = '.\workshop0606data\all_user_firstandsecond_event_0701_second.xlsx';
[fileType, sheets] = xlsfinfo(xlsFile);

total_sensitivity = [];
total_precision = [];

for i = 2:length(sheets)
    % 技師答案
    [NUM{1},TXT{1},RAW{1}] = xlsread(xlsFile, string(sheets(i)));
    event = RAW{1,1}(:, 4:6);
    oa = event(find(event(:,1)=="ARO SPONT"), :);
    myoa = zeros(1, 742*30);
    for j = 1:height(oa)
        myoa(round(cell2mat(oa(j, 2))):round(cell2mat(oa(j, 3)))) = 1;
    end
    
    % 標準答案
    aasm2020_event = zeros(1, 742*30);
    aasm2020 = readtable('.\workshop0606data\workshop_golden_event.csv');
    for j = 1:height(aasm2020)
        if string(aasm2020(j, 1).Var1) == "ARO SPONT"
            aasm2020_event(1, round(aasm2020(j, 2).Var2) : round(aasm2020(j, 2).Var2 + aasm2020(j, 3).Var3)) = 1;
        end
    end
    
    %% confuse matrix
    % tp 成功偵測出apnea
    % tn 成功偵測出無事件(不考量)
    % fp 偵測錯誤
    % fn 漏抓
    tp = 0;
    fp = 0;
    fn = 0;
    ansoa = aasm2020_event(1, :);
    
    cont = 0;
    es = 0;
    ee = 0;
    for j = 1:length(ansoa)
        if (ansoa(j) == 1) && (cont == 0)
            es = j;
            cont = 1;
        elseif (ansoa(j) == 0) && (cont == 1)
            ee = j - 1;
            cont = 0;
            if sum(myoa(es:ee)) > 0
                tp = tp + 1;
            else
                fn = fn + 1;
            end
        end
    end
    for j = 1:length(myoa)
        if (myoa(j) == 1) && (cont == 0)
            es = j;
            cont = 1;
        elseif (myoa(j) == 0) && (cont == 1)
            ee = j - 1;
            cont = 0;
            if sum(ansoa(es:ee)) == 0
                fp = fp + 1;
            end
        end
    end
    
    % Sensitivity(TP/(TP+FN))
    % Precision(TP/(TP+FP))
    
    sensitivity = tp / (tp+fn);
    precision = tp / (tp+fp);
    
    total_sensitivity(end+1) = sensitivity;
    total_precision(end+1) = precision;
    
end

total_sensitivity = total_sensitivity.';
total_precision = total_precision.';