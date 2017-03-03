%%%Automatically perform all EEG pre-processing steps

%% Common code

clear all
close all
clc

path = cd;
fb = strfind(path,filesep);
path = path(1:fb(end));
out_path = char([path, 'data', filesep, 'processed_new', filesep]);%%%PATH TO BEHAVIORAL DATA FILES
eeg_path = char([out_path, 'postinterp', filesep]); %%%PATH TO EEG DATA FILES
erp_path = char([out_path, 'erp', filesep]); %%%PATH TO ERP OUTPUT
mkdir(erp_path);
beh_path = char([path, 'data', filesep, 'orig', filesep, 'game_logs', filesep]); %%%PATH TO BEHAVIORAL DATA FILES
clean_path = char([path, 'scripts', filesep, 'EEG_Clean']); %%%PATH TO BEHAVIORAL DATA FILES
lab_path = path(1:fb(end-1));
lab_path = char([lab_path, 'workspace\eeglab\']); %%%PATH TO EEGLAB
chan_path = char([lab_path, 'plugins\dipfit2.3\standard_BESA\standard-10-5-cap385.elp']); %%%PATH TO CAP FILE

lab_path(strfind(lab_path,'\')) = filesep;
chan_path(strfind(chan_path,'\')) = filesep;
clean_path(strfind(clean_path,'\')) = filesep;

addpath(lab_path); %%%ADD PATH TO EEGLAB FUNCTIONS
addpath(clean_path); %%%ADD PATH TO EEGLAB FUNCTIONS
eeglab; %%%LOAD EEGLAB FUNCTIONS

pop_editoptions('option_single', false, 'option_savetwofiles', false); %%% MEMORY MANAGEMENT STUFF
close all

%% Process subjects

for subject = 1:1 %%% RUN FOR ONE OR ALL SUBJECTS

    %%

    %%% STEP 1. LOAD FILE
    sid = ['subject' int2str(subject)];
    fname1 = char([eeg_path, sid '_postinterp.set']);

    EEG = pop_loadset('filename',fname1);
    EEG = eeg_checkset( EEG );

    EEGorig = EEG;

    %%%for event = {'vlner-increased'}
    for event = {'ship-destroyed' 'fortress-destroyed' 'vlner-reset'}

        EEG = pop_selectevent( EEGorig, 'type',{event},'deleteevents','on');
        EEG = eeg_checkset( EEG );

        fname3 = char([sid, '-', char(event)]);

        EEG = pop_epoch( EEG, {  }, [-0.200 0.800], 'newname', fname3, 'epochinfo', 'yes');
        EEG = pop_rmbase( EEG, [-200 0]);
        EEG = eeg_checkset( EEG );

        %%
        %%% STEP 3 - Detect and interpolate channels that were only bad during some Epochs
        EEG = clean_epochs_mmw(EEG,3.5, 3.5, 3.5);
        EEG = eeg_checkset( EEG );

        %%
        %%% STEP 4 (optional) - Delete epochs that still have extreme values
        %%% +/- 100mV
        EEG = pop_eegthresh(EEG,1,[1:128] ,-100,100,-0.20117,1,0,1);
        EEG = eeg_checkset( EEG );

        %%
        %%% STEP 5 -- Only retain thrust event epochs.
        %EEG = pop_selectevent( EEG, 'latency','-.05<=.05', 'type',{'explode-smallhex'},'sdid',sdid_range,'deleteevents','on','deleteepochs','on','invertepochs','off');
        EEG = pop_selectevent( EEG, 'latency','-.05<=.05', 'type',{event},'deleteevents','on','deleteepochs','on','invertepochs','off');
        EEG = eeg_checkset( EEG );

        fname4 = char([out_path, 'erp', filesep, fname3, '.set']);
        pop_saveset( EEG, 'filename', fname4, 'version', '7.3');

        [ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, EEG);

    end

    fname5 = char([out_path, 'erp', filesep, sid, '-comperp.png']);
    pop_comperp( ALLEEG, 1, [1:3] , [], 'addavg','off','addstd','off','addall','on','diffavg','off','diffstd','off','tplotopt',{'colors' {'b' 'r' 'g'} 'ydir' -1});
    r = 150; % pixels per inch
    set(gcf, 'PaperUnits', 'inches', 'PaperPosition', [0 0 1680 1050]/r);
    print(gcf,'-dpng',sprintf('-r%d',r),fname5);

    for chan = {EEG.chanlocs([65, 68, 73, 84, 95, 40, 50, 56, 63, 64]).labels}
        fname6 = char([out_path, 'erp', filesep, sid, '-', char(chan), '.png']);
        pop_comperp( ALLEEG, 1, [1:3] , [], 'addavg','off','addstd','off','addall','on','diffavg','off','diffstd','off','tplotopt',{'chans' [find(strcmp(chan,{EEG.chanlocs.labels}))] 'ydir' -1});
        r = 150; % pixels per inch
        set(gcf, 'PaperUnits', 'inches', 'PaperPosition', [0 0 800 600]/r);
        print(gcf,'-dpng',sprintf('-r%d',r),fname6);
    end

    ALLEEG = pop_delset(ALLEEG, [1:3]);
    close all
    clc
end
