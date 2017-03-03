from __future__ import print_function

import os, sys

import math
import h5py
import scipy
from scipy import signal
import scipy.misc
from scipy.interpolate import griddata
from sklearn.preprocessing import scale
import mne
mne.utils.set_config('MNE_USE_CUDA', 'true')

import numpy as np
import json

def cart2sph(x, y, z):
    x2_y2 = x**2 + y**2
    r = math.sqrt(x2_y2 + z**2)
    elev = math.atan2(z, math.sqrt(x2_y2))
    az = math.atan2(y, x)
    return r, elev, az

def pol2cart(theta, rho):
    return rho * math.cos(theta), rho * math.sin(theta)

def azim_proj(pos):
    [r, elev, az] = cart2sph(pos[0], pos[1], pos[2])
    return pol2cart(az, math.pi / 2 - elev)

def gen_image(eeg, locs):
    features = []
    for i in xrange(len(eeg)):
        s = np.absolute(np.fft.fft(eeg[i])[:h2])
        s = s / max(s)
        s = map(np.sum, [s[2:4], s[4:8], s[8:16]])
        features.append(s)
    features = np.array(features).transpose()

    normalize = False
    edgeless = False
    n_gridpoints = 32
    nElectrodes = locs.shape[0]
    assert features.shape[1] % nElectrodes == 0
    n_colors = features.shape[1] / nElectrodes
    feat_array_temp = []
    for c in range(n_colors):
        feat_array_temp.append(features[:, c * nElectrodes : nElectrodes * (c+1)])
    nSamples = features.shape[0]
    grid_x, grid_y = np.mgrid[
                     min(locs[:, 0]):max(locs[:, 0]):n_gridpoints*1j,
                     min(locs[:, 1]):max(locs[:, 1]):n_gridpoints*1j
                     ]

    temp_interp = []
    for c in range(n_colors):
        temp_interp.append(np.zeros([nSamples, n_gridpoints, n_gridpoints]))
    # Generate edgeless images
    if edgeless:
        min_x, min_y = np.min(locs, axis=0)
        max_x, max_y = np.max(locs, axis=0)
        locs = np.append(locs, np.array([[min_x, min_y], [min_x, max_y],[max_x, min_y],[max_x, max_y]]),axis=0)
        for c in range(n_colors):
            feat_array_temp[c] = np.append(feat_array_temp[c], np.zeros((nSamples, 4)), axis=1)
    # Interpolating
    for i in xrange(nSamples):
        for c in range(n_colors):
            temp_interp[c][i, :, :] = griddata(locs, feat_array_temp[c][i, :], (grid_x, grid_y),
                                    method='cubic', fill_value=np.nan)
    # Normalizing
    for c in range(n_colors):
        if normalize:
            temp_interp[c][~np.isnan(temp_interp[c])] = \
                scale(temp_interp[c][~np.isnan(temp_interp[c])])
        temp_interp[c] = np.nan_to_num(temp_interp[c])

    temp_interp = np.asarray(temp_interp)
    temp_interp = np.swapaxes(temp_interp, 1, 3)

    return temp_interp[0]

if __name__ == "__main__":

    alias = "features4"

    for sid in xrange(1,11):

        print("============================")
        print("Subject %d" % (sid))
        print("============================")

        base = os.path.dirname(os.path.abspath(__file__))
        setfile = os.path.join(base, "../data/subject%d_postinterp.set" % (sid))
        data = h5py.File(setfile, 'r', driver="core")
        sfreq = data['EEG']['srate'].value[0][0]
        ch_names = ["".join([chr(i) for i in data[ch[0]]]) for ch in data['EEG']['chanlocs']['labels'].value]
        ch_types = ["eeg"] * len(ch_names)
        montage = mne.channels.read_montage("standard_1005")
        info = mne.create_info(ch_names, sfreq, ch_types=ch_types, montage=montage)
        raw = data['EEG']['data'].value.transpose()
        raw = mne.io.RawArray(raw, info)
        print(raw.info)

        #if False:
        eventfile = os.path.join(base, "../data/subject%d/subject%d-eve.lst" % (sid, sid))
        eventnamefile = os.path.join(base, "../data/subject%d/subject%d-eve.json" % (sid, sid))
        events = mne.read_events(eventfile)

        with open(eventnamefile, "r") as f:
            event_ids = json.load(f)
        print(event_ids)

        drop_events = ["release-thrust", "release-fire", "ship-destroyed", "hit-fortress", "missile-fired"]
        keep_events = ["hold-fire", "hold-thrust"]
        epochs = {}
        training_idx = {}
        test_idx = {}
        for k,v in event_ids.items():
            if k not in keep_events:
                continue
            print
            print(k)
            epochs[k] = mne.Epochs(raw, events=events, event_id=v,
                tmin=-.5, tmax=0, baseline=None, detrend=0,
                add_eeg_ref=False, proj=False, reject=None,
                reject_by_annotation=False, verbose="DEBUG")
            epochs[k].drop_bad(None, None, verbose="DEBUG")
            epochsN = len(epochs[k])
            indices = np.random.permutation(epochsN)
            trainN = int(np.ceil(epochsN*.8))
            training_idx[k], test_idx[k] = indices[:trainN], indices[trainN:]

        locs = np.array([azim_proj(c['loc'][:3]) for c in raw.info['chs']])

        h = int(sfreq/2)
        h2 = int(h/2)

        for k in epochs:
            features_dir = os.path.join(base,"../%s/subject%d" % (alias, sid))
            for m in ["train","test"]:
                if m == "train":
                    idx = training_idx[k]
                else:
                    idx = test_idx[k]
                d = os.path.join(os.path.join(features_dir,m),k)
                if not os.path.exists(d):
                    os.makedirs(d)
                for j in idx:
                    out = gen_image(epochs[k][j].get_data()[0], locs)
                    scipy.misc.imsave(os.path.join(d,'%s%05d.png' % (k, j)), out)
