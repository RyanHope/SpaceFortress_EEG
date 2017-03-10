%%%Automatically perform all EEG pre-processing steps

%% Common code

clear all
close all
clc

basepath = cd;
fb = strfind(basepath,filesep);
basepath = basepath(1:fb(end));
out_path = fullfile(basepath, 'data', 'processed');
eeg_path = fullfile(out_path, 'postinterp');
lab_path = basepath(1:fb(end-1));
lab_path = fullfile(lab_path, 'workspace','eeglab');

addpath(lab_path);
eeglab;

close all
clc

%%
stats = [];
for subject = [1:3 5:17]
    sid = ['subject' int2str(subject)];
    fname1 = fullfile(eeg_path, [sid '_postinterp.set']);
    EEG = pop_loadset('filename',fname1);
    EEG = eeg_checkset(EEG);
    stats(subject,:) = [length(find(EEG.etc.clean_channel_mask==0)) length(find(EEG.etc.clean_sample_mask==0))/length(EEG.etc.clean_sample_mask) size(EEG.icaact,1)];
    stats(subject,:)
end
