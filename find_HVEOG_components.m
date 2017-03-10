function [v_mask h_mask] = find_HVEOG_components(signal,window_len,window_overlap,VEOG_corr,HEOG_corr)
%   EEG = clean_components(signal,window_len,window_overlap,VEOG_corr,HEOG_corr)
%   signal = EEG data.
%   window_len = length of window (in seconds) for comupting correlation
%   window_overlap = percent of overlap in sliding window for computing correlation
%   VEOG_corr = correlation between time-varying activation of component and VEOG channel for selection
%   HEOG_corr = correlation between time-varying activation of component and HEOG channel for selection

if ~exist('window_len','var') || isempty(window_len); window_len = 5; end
if ~exist('window_overlap','var') || isempty(window_overlap); window_overlap = .5; end
% if ~exist('VEOG_corr','var') || isempty(VEOG_corr); VEOG_corr = .8; end
% if ~exist('HEOG_corr','var') || isempty(HEOG_corr); HEOG_corr = .8; end

signal.data = double(signal.data);
[~,S] = size(signal.data);
N = window_len*signal.srate;
wnd = 0:N-1;
offsets = round(1:N*(1-window_overlap):S-N);

W = length(offsets);

fprintf('Scanning for bad components...\n');

labs = upper({signal.chanlocs.labels});

%%%Requesting VEOG correction?
if isempty(VEOG_corr) == 0
    VEOG = find(strcmp(labs,'VEOG'));
    if isempty(VEOG)
        
        fp1 = find(strcmp(labs,'FP1'));
        fp2 = find(strcmp(labs,'FP2'));
        
        VEOG = mean(signal.data([fp1 fp2],:),1);
    else
        VEOG = signal.data(VEOG,:);
    end
end

%%%Requesting HEOG correction?
if isempty(HEOG_corr) == 0
    HEOG = find(strcmp(labs,'HEOG'));
    HEOG = signal.data(HEOG,:);
end

for c = 1 : W
    XX = signal.icaact(:,offsets(c)+wnd)';
    
    if isempty(VEOG_corr) == 0
        VX = VEOG(offsets(c)+wnd)'; %%%IC correlation with VEOG signal
        VCORR = corr(VX,XX);
        VMAT(c,:) = VCORR;
    end
    
    if isempty(HEOG_corr) == 0
        HX = HEOG(offsets(c)+wnd)'; %%%IC correlation with HEOG signal
        HCORR = corr(HX,XX);
        HMAT(c,:) = HCORR;
    end
end

%%%Could be positive or negative, so take absolute value
if isempty(VEOG_corr) == 0
    VMAT = abs(mean(VMAT));
    v_mask = find(VMAT > VEOG_corr);
else
    v_mask = [];
end

if isempty(HEOG_corr) == 0
    HMAT = abs(mean(HMAT));
    h_mask = find(HMAT > HEOG_corr);
else
    h_mask = [];
end

%signal = pop_subcomp( signal, [v_mask h_mask], 0);
%signal = eeg_checkset( signal );

%field = {'VEOG';'HEOG';'Noise'};

%ICAnotes = struct(field{1},{v_mask},field{2},{h_mask});
%signal.etc.ICAnotes = ICAnotes;