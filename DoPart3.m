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
erp_path = fullfile(out_path, 'erp');
beh_path = fullfile('data', 'orig', 'game_logs');
lab_path = basepath(1:fb(end-1));
lab_path = fullfile(lab_path, 'workspace','eeglab');
mkdir(erp_path);

addpath(lab_path);
eeglab;

close all

%% Process subjects

for subject = [1:3 5:17] %%% RUN FOR ONE OR ALL SUBJECTS

    %%

    %%% LOAD FILE
    sid = ['subject' int2str(subject)];
    fname1 = fullfile(eeg_path, [sid '_postinterp.set']);

    EEG = pop_loadset('filename',fname1);
    EEG = eeg_checkset(EEG);

    EEGorig = EEG;

    for event = {'ship-destroyed' 'fortress-destroyed' 'vlner-reset'}

        EEG = pop_selectevent( EEGorig, 'type',{event},'deleteevents','on');
        EEG = eeg_checkset( EEG );

        fname3 = char([sid, '-', char(event)]);

        EEG = pop_epoch(EEG, {  }, [-1.0 2.000], 'newname', fname3, 'epochinfo', 'yes');
        EEG = pop_rmbase( EEG, [-1000 0]);
        EEG = eeg_checkset(EEG);

        %%% Detect and interpolate channels that were only bad during some Epochs
        EEG = clean_epochs_mmw(EEG,3.5, 3.5, 3.5);
        EEG = eeg_checkset(EEG);

        %%% Delete epochs that still have extreme values (+/- 100mV)
        EEG = pop_eegthresh(EEG,1,[1:128] ,-100,100,-0.20117,1,0,1);
        EEG = eeg_checkset(EEG);

        %%% Only retain {event} epochs.
        EEG = pop_selectevent(EEG, 'latency','-.05<=.05', 'type',{event},'deleteevents','on','deleteepochs','on','invertepochs','off');
        EEG = eeg_checkset(EEG);

        fname4 = fullfile(out_path, 'erp', [fname3, '.set']);
        pop_saveset(EEG, 'filename', fname4, 'version', '7.3');

        [ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, EEG);

    end

    %%% Plot and save 2D map of all ERPs
    fname5 = fullfile(out_path, 'erp', [sid, '-comperp.png']);
    pop_comperp( ALLEEG, 1, [1:3] , [], 'addavg','off','addstd','off','addall','on','diffavg','off','diffstd','off','tplotopt',{'colors' {'b' 'r' 'g'} 'ydir' -1});
    r = 150; % pixels per inch
    set(gcf, 'PaperUnits', 'inches', 'PaperPosition', [0 0 1680 1050]/r);
    print(gcf,'-dpng',sprintf('-r%d',r),fname5);

    %%% Plot and save single midline ERPs
    for chan = {EEG.chanlocs([65, 68, 73, 84, 95, 40, 50, 56, 63, 64]).labels}
        fname6 = fullfile(out_path, 'erp', [sid, '-', char(chan), '.png']);
        pop_comperp( ALLEEG, 1, [1:3] , [], 'addavg','off','addstd','off','addall','on','diffavg','off','diffstd','off','tplotopt',{'chans' [find(strcmp(chan,{EEG.chanlocs.labels}))] 'ydir' -1});
        r = 150; % pixels per inch
        set(gcf, 'PaperUnits', 'inches', 'PaperPosition', [0 0 800 600]/r);
        print(gcf,'-dpng',sprintf('-r%d',r),fname6);
    end

    ALLEEG = pop_delset(ALLEEG, [1:3]);
    close all
    clc
end
