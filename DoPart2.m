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
out_path = fullfile(basepath, 'data', 'processed');
ica_path = fullfile(out_path, 'postica');
interp_path = fullfile(out_path, 'postinterp');
interp2_path = fullfile(out_path, 'postinterp_downsampled');
lab_path = basepath(1:fb(end-1));
lab_path = fullfile(lab_path, 'workspace','eeglab');
mkdir(interp_path);
mkdir(interp2_path);

addpath(lab_path);
eeglab;

close all

%% Process subjects

stats = [];
for subject = [1:3 5:17]

    %%% LOAD FILE
    sid = ['subject' int2str(subject)];
    fname1 = fullfile(ica_path, [sid '_postica.set']);
    fname2 = fullfile(interp_path, [sid '_postinterp.set']);
    fname3 = fullfile(interp2_path, [sid '_postinterp_downsampled.set']);
    EEG = pop_loadset('filename',fname1);
    EEG = eeg_checkset(EEG);

    %find_HVEOG_components(EEG,30,.5,.4,.4)

    %%% FLAG AND REMOVE ARTIFACT COMPONENTS
    field = {'VEOG';'HEOG'};
    if subject == 1
        v_mask = 1
        h_mask = []
    elseif subject == 2
        v_mask = 2
        h_mask = 8
    elseif subject == 3
        v_mask = 1
        h_mask = 18
    elseif subject == 5
        v_mask = 1
        h_mask = []%36
    elseif subject == 6
        v_mask = 1
        h_mask = []
    elseif subject == 7
        v_mask = 2
        h_mask = []%18
    elseif subject == 8
        v_mask = 1
        h_mask = 10
    elseif subject == 9
        v_mask = 1
        h_mask = 7
    elseif subject == 10
        v_mask = 1
        h_mask = 17
    elseif subject == 11
        v_mask = 1
        h_mask = 7
    elseif subject == 12
        v_mask = 1
        h_mask = []
    elseif subject == 13
        v_mask = 1
        h_mask = []
    elseif subject == 14
        v_mask = 1
        h_mask = []%10
    elseif subject == 15
        v_mask = 1
        h_mask = 39
    elseif subject == 16
        v_mask = 1
        h_mask = []
    elseif subject == 17
        v_mask = 1
        h_mask = []
    end
    EEG.reject.gcompreject([v_mask h_mask]) = 1;
    EEG = pop_subcomp(EEG, [], 0);
    EEG.etc.ICAnotes = struct(field{1},{v_mask},field{2},{h_mask});

    EEG = eeg_checkset(EEG);

    %%% Keep only data channels
    EEG = pop_select(EEG,'nochannel',{EEG.etc.chanlocsOrig(128:end).labels 'HEOG' 'VEOG'});
    EEG = eeg_checkset(EEG);

    % Interpolate all the removed channels
    % NOTE: when passed a full channel structure (2nd arg) missing channs
    % as compared to EEG are interpolated
    EEG = pop_interp(EEG, EEG.etc.chanlocsOrig(1:128), 'spherical');

    stats(subject,:) = [length(find(EEG.etc.clean_channel_mask==0)) length(find(EEG.etc.clean_sample_mask==0))/length(EEG.etc.clean_sample_mask) size(EEG.icaact,1)];
    stats(subject,:)

    EEG.setname = [sid '-postinterp'];
    pop_saveset(EEG, 'filename', fname2, 'version', '7.3');

    EEG = pop_resample(EEG, 100);
    EEG = eeg_checkset(EEG );
    EEG.setname = [sid '-postinterp-downsampled'];
    pop_saveset(EEG, 'filename', fname3, 'version', '7.3');

    close all
    clc
end
