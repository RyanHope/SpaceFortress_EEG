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
out_path = fullfile(basepath, 'data', 'processed_new');
ica_path = fullfile(out_path, 'postica');
interp_path = fullfile(out_path, 'postinterp');
lab_path = basepath(1:fb(end-1));
lab_path = fullfile(lab_path, 'workspace','eeglab');
mkdir(erp_path);

addpath(lab_path);
eeglab;

close all

%% Process subjects

for subject = 1:1

    %%% LOAD FILE
    sid = ['subject' int2str(subject)];
    fname1 = fullfile(eeg_path, [sid '_postica.set']);
    EEG = pop_loadset('filename',fname1);
    EEG = eeg_checkset(EEG);

    %%% FLAG AND REMOVE ARTIFACT COMPONENTS
    EEG = clean_components(EEG,30,.5,.4,.4);
    EEG = eeg_checkset(EEG);

    %%% Keep only data channels
    EEG = pop_select(EEG,'nochannel',{EEG.etc.chanlocsOrig(128:end).labels 'HEOG' 'VEOG'});
    EEG = eeg_checkset(EEG);

    % Interpolate all the removed channels
    % NOTE: when passed a full channel structure (2nd arg) missing channs
    % as compared to EEG are interpolated
    EEG = pop_interp(EEG, EEG.etc.chanlocsOrig(1:128), 'spherical');

    EEG.setname = [sid '-cleaned'];
    pop_saveset(EEG, 'filename', fname3, 'version', '7.3');

    close all
    clc
end
