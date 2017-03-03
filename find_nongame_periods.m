function nonGamesPeriods = find_nongame_periods(EEG)
    nonGamesPeriods = [];
    start = 1;
    for i=1:length(EEG.event)
        if strcmp(EEG.event(i).type, 'game-start')
            nonGamesPeriods = cat(1, nonGamesPeriods, [start EEG.event(i).latency-1]);
        elseif strcmp(EEG.event(i).type, 'game-end')
            start = EEG.event(i).latency+1;
        end
    end