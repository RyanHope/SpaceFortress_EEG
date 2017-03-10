%%%Automatically perform all EEG pre-processing steps

%%% NOTE: This script requires the clean_rawdata plugin for eeglab
%%% NOTE: This script uses CUDAICA which right now only builds on linux/osx

%% Common code

clear all
close all
clc

basepath = cd;
fb = strfind(basepath,filesep);
basepath = basepath(1:fb(end));
eeg_path = fullfile(basepath,'data','orig','raw_eeg');
beh_path = fullfile(basepath,'data','orig','game_logs');
out_path = fullfile(basepath,'data','processed');
lab_path = basepath(1:fb(end-1));
lab_path = fullfile(lab_path,'workspace','eeglab');
loc_file = fullfile(lab_path,'plugins','dipfit2.3','standard_BEM','elec','standard_1005.elc');

addpath(lab_path);
eeglab;

close all

%% Process subjects

for subject = 5:17

    %%% LOAD .bdf and external event file
    sid = ['subject' int2str(subject)];
    fname1 = fullfile(eeg_path, [sid '.bdf']);
    fname1
    fname2 = fullfile(out_path, 'eeg_event_files', [sid '.ext']);
    mkdir(fullfile(out_path, 'postica', filesep));
    fname3 = fullfile(out_path, 'postica', filesep, [sid '_postica.set']);
    EEG = pop_biosig(fname1, 'importevent', 'off', 'importannot', 'off', 'ref', [129 130]);
    EEG = eeg_checkset(EEG);
    EEG = pop_importevent(EEG, 'event', fname2, 'fields', {'latency' 'game' 'type'}, 'timeunit', 1, 'optimalign', 'off', 'append', 'no');
    EEG = eeg_checkset(EEG);

    %%% Swap channels
    swaps1 = {};
    swaps2 = {};
    if subject == 9
        swaps1 = {'ECG'};
        swaps2 = {'FT9'};
    end

    if length(swaps1) > 0
        fv = [];
        for i = 1:length(swaps1)
            fv(i,1) = find(strcmp(swaps1{i},{EEG.chanlocs.labels}));
            fv(i,2) = find(strcmp(swaps2{i},{EEG.chanlocs.labels}));
        end
        data = EEG.data;
        reorder = data(fv(:,1),:);
        data(fv(:,2),:) = reorder;
        EEG.data = data;
        EEG = eeg_checkset(EEG);
    end

    %%% Import channel locations
    EEG = pop_chanedit(EEG, 'lookup',loc_file);
    EEG = eeg_checkset(EEG);

    %%% Remove offset (subtract average of each channel)
    for numChans = 1:size(EEG.data,1);
        EEG.data(numChans, :) = EEG.data(numChans, :) - mean(EEG.data(numChans, :));
    end
    EEG = eeg_checkset(EEG);

    %%% High-pass filter the data at 0.1-Hz
    EEG = pop_eegfiltnew(EEG, 0.1, 0, 16896, 0, [], 0);
    EEG = eeg_checkset(EEG);

    %%% 40-Hz low-pass filer (really 47.5-Hz)
    EEG = pop_eegfiltnew(EEG, [], 40);
    EEG = eeg_checkset(EEG);

    %%% Remove non-game periods
    EEG = eeg_eegrej(EEG, find_nongame_periods(EEG));
    EEG = eeg_checkset(EEG);

    %%% DRL/CMS issue for entire second game, fixed before 3rd game
    if subject == 2
        EEG = eeg_eegrej(EEG, [91316 154003] );
        EEG = eeg_checkset(EEG);
    end

    % Apply clean_rawdata() to reject bad channels and windows
    % NOTE: highpass and burst (ASR) are disabled
    % NOTE: clean_rawdata removes bad channels from EEG
    % NOTE: use vis_artifacts(EEG, originalEEG) to compare new and old data
    originalEEG = EEG;
    EEG = clean_rawdata(originalEEG, 5, -1, 0.7, 4.5, -1, 0.8);

    %%% Drop samples that were marked bad so that we can restore the
    %%% occular channels
    sample_mask = contiguous(EEG.etc.clean_sample_mask,1);
    sample_mask = sample_mask(2);
    sample_mask = sample_mask{:};
    originalEEG = pop_select(originalEEG, 'point', sample_mask);

    % Mark known bad channels
    bads = {};
    if subject == 1
        bads = {'Fp1','Fpz'};
    elseif subject == 2
        bads = {'Fpz'};
    elseif subject == 13
        bads = {'P2','CCP3h'};
    elseif subject == 15
        bads = {'TP10','P10'};
    elseif subject == 17
        bads = {'FTT9h','PPO1h','CP4','CP6'};
    end
    if length(bads) > 0
        for i = 1:length(bads)
            EEG.etc.clean_channel_mask(find(strcmp(bads{i},{EEG.chanlocs.labels}))) = 0;
        end
    end
    EEG = eeg_checkset(EEG);

    %%% Make copy of EEG for ICA
    EEGica = EEG;

    %%% 1Hz highpass and downsample for ICA
    EEGica = pop_eegfiltnew(EEGica, [], 1, 1690, true, [], 0);
    EEGica = eeg_checkset(EEGica);
    EEGica = pop_resample(EEGica, 128);
    EEGica = eeg_checkset(EEGica);

    %%% Drop non-data channels to avoid rank deficiency
    EEGica = pop_select(EEG, 'nochannel', cell2mat(arrayfun(@(x) find(strcmp(x,{EEGica.chanlocs.labels})), {originalEEG.chanlocs(129:end).labels},'un',0)));
    EEGica = eeg_checkset(EEGica);

    %%% Run ICA
    EEGica = pop_runica(EEGica, 'icatype','cudaica','extended',1,'verbose',1,'maxsteps',1024);
    EEG.icaweights = EEGica.icaweights;
    EEG.icasphere = EEGica.icasphere;
    EEG.icachansind = EEGica.icachansind;
    EEG = eeg_checkset(EEG);

    %%% Construct new occular channels
    HEOG = [find(strcmp({originalEEG.chanlocs.labels},'LO1')) find(strcmp({originalEEG.chanlocs.labels},'IO2'))];
    VEOG = [find(strcmp({originalEEG.chanlocs.labels},'SO1')) find(strcmp({originalEEG.chanlocs.labels},'IO1'))];
    EEG.nbchan = EEG.nbchan+2;
    EEG.data(end+1,:) = originalEEG.data(HEOG(1),:)-originalEEG.data(HEOG(2),:);
    EEG.data(end+1,:) = originalEEG.data(VEOG(1),:)-originalEEG.data(VEOG(2),:);
    EEG.chanlocs(end+1).labels = 'HEOG';
    EEG.chanlocs(end+1).labels = 'VEOG';
    EEG = eeg_checkset(EEG);

    %%% Backup original chanlocs
    EEG.etc.chanlocsOrig = originalEEG.chanlocs;

    %%% Save cleaned ICA data
    EEG.setname = [sid '-postica'];
    pop_saveset(EEG, 'filename', fname3, 'version', '7.3');

    close all
    clc
end
