#!/usr/bin/env python

"""
Parse a SF logfile and BDF file and generate EEGLAB compat event file
"""

from __future__ import print_function, division

import sys, os
import csv
import glob
import mne
import argparse
import operator
import json
import numpy as np
import zlib

if __name__ == '__main__':

    parser = argparse.ArgumentParser()
    parser.add_argument('subject_dir')
    parser.add_argument('output_dir')
    args = parser.parse_args()
    if os.path.isdir(args.subject_dir):
        base, sid = os.path.split(args.subject_dir)
        base, _ = os.path.split(base)
        bdf_file = os.path.join(base,'raw_eeg','%s.bdf' % sid)

        raw = mne.io.read_raw_edf(bdf_file)
        eeg_events = mne.find_events(raw, stim_channel='STI 014', shortest_event=1)

        start_times = []
        for e in eeg_events:
            if e[1]==0 and e[2]==1:
                start_times.append([e[0], e[0]/raw.info["sfreq"]])

        # unique_game_events = {}
        # game_events = []
        game_events2 = []
        death_times = []

        for f in glob.glob("%s/*.evt" % args.subject_dir):
            g = int(os.path.split(f)[-1].split(".")[0].split("-")[-1])
            with open(f, "r") as fin:
                lines = [l.strip().split(" ") for l in fin.readlines()]
                gs = float(lines[0][1])
                N = len(lines)
                # epoch = 0
                for i in xrange(N):
                    e = lines[i]
                    game_marker = None
                    et = float(e[1]) - gs
                    # if int(np.floor(int(e[0])/5000.)+1) > epoch:
                    #     epoch += 1
                    #     if len(e) < 3:
                    #         e.append("epoch")
                    #     else:
                    #         e[2] = "%s,%s" % (e[2], "epoch")
                    if i == 0:
                        game_marker = "game-start"
                    elif i == (N-1):
                        game_marker = "game-end"
                    if game_marker != None:
                        if len(e) < 3:
                            e.append(game_marker)
                        else:
                            e[2] = "%s,%s" % (e[2], game_marker)
                    if len(e) == 3:
                        for ee in e[2].split(","):
                            # if not ee in unique_game_events:
                            #     unique_game_events[ee] = zlib.adler32(ee)
                            # game_events.append([int((et+start_times[g-1][1])*raw.info["sfreq"]), g, unique_game_events[ee]])
                            game_events2.append([et+start_times[g-1][1], g, ee])
                            # if ee == "ship-destroyed":
                            #     death_times.append(game_events2[-1][0])

        # game_events = sorted(game_events, key=operator.itemgetter(0, 1))
        game_events2 = sorted(game_events2, key=operator.itemgetter(0, 1))
        # epoch_base = 0
        # for i in xrange(len(game_events2)):
        #     if i > 0 and game_events2[i][1] != game_events2[i-1][1]:
        #         epoch_base = game_events2[i-1][-1]
        #     game_events2[i].append(epoch_base + game_events2[i][-1])

        # death_times.append(float("inf"))
        # next_death = 0
        # smalldeath_id = 0
        # for i in xrange(len(game_events2)):
        #     sdid = -1
        #     if game_events2[i][2] == "explode-smallhex":
        #         smalldeath_id += 1
        #         sdid = smalldeath_id
        #     game_events2[i].append(sdid)
        #     game_events2[i].append(np.ceil(sdid/10.))
        #     game_events2[i].append(np.ceil(game_events2[i][1]/10.))
        #     if game_events2[i][0] > death_times[next_death]:
        #         next_death += 1
        #     nd = death_times[next_death] - game_events2[i][0]
        #     game_events2[i].append(nd)
        #     for threshold in [1, 2, 3, float("Inf")]:
        #         if nd <= threshold:
        #             game_events2[i].append("<=%s" % str(threshold))
        #             break

        # print("Unique game events: %s" % str(unique_game_events.keys()))

        # with open(os.path.join(args.output_dir, "%s-eve.lst" % (sid)), "wb") as fout:
        #     writer = csv.writer(fout, delimiter="\t")
        #     for ge in game_events:
        #         writer.writerow(ge)
        # with open(os.path.join(args.output_dir, "%s-eve.json" % (sid)), "wb") as fout:
        #     json.dump(unique_game_events, fout)
        if not os.path.isdir(args.output_dir):
            os.makedirs(args.output_dir)
        with open(os.path.join(args.output_dir, "%s.ext" % (sid)), "wb") as fout:
            writer = csv.writer(fout, delimiter="\t")
            for ge in game_events2:
                writer.writerow(ge)
