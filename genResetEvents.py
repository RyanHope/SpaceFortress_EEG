#!/usr/bin/env python

"""
Parse a SF logfile and BDF file and generate EEGLAB compat event file
"""

from __future__ import print_function, division

import sys, os
import csv
import glob
import json
import argparse
import numpy as np

from sf_util import *

if __name__ == '__main__':

    parser = argparse.ArgumentParser()
    parser.add_argument('subject_dir')
    parser.add_argument('output_dir')
    args = parser.parse_args()

    DEBUG = False

    if os.path.isdir(args.subject_dir):
        sid = os.path.split(args.subject_dir)[1]
        if not os.path.isdir(args.output_dir):
            os.makedirs(args.output_dir)
        log_files = glob.glob("%s/%s-1-*.tsv" % (args.subject_dir, sid))
        events = [None] * len(log_files)
        for log_file in log_files:
            if DEBUG:
                sys.stderr.write("log file: %s\n" % log_file)
            base = os.path.splitext(log_file)[0]
            _, session, game = os.path.split(base)[1].split("-")
            session = int(session)
            game = int(game)
            sinfo = [sid, session, game]
            fin = open(log_file, "r")
            header = fin.readline().split("\t")
            events[game-1] = []
            if DEBUG:
                for i in xrange(len(header)):
                    print(i,header[i])
            rows = [parseRow(r.strip().split("\t")) for r in fin.readlines()]
            R = len(rows)
            total_shots = 0
            for i in xrange(len(rows)):
                if rows[i][37] > total_shots:
                    total_shots = rows[i][37]
                if rows[i][6] > 0:
                    rows[i].append(np.hypot(rows[i][9],rows[i][10]))
                else:
                    rows[i].append(float("nan"))
                if i < R-1:
                    #FIND VLNER CHANGE
                    j = i + 1
                    if rows[j][23] < rows[i][23] and rows[j][15] != -1:
                        nextShotLatency = 0
                        nextHitLatency = 0
                        if rows[i][47] == 1 and rows[j][47] == 0:
                            while rows[j+nextShotLatency][47] == 0:
                                nextShotLatency += 1
                                if j+nextShotLatency >= R:
                                    nextShotLatency = float("inf")
                                    break
                            if nextShotLatency != float("inf"):
                                nextHitLatency = nextShotLatency
                                while rows[j+nextHitLatency][47] >= rows[j+nextHitLatency-1][47]:
                                    nextHitLatency += 1
                                    if j+nextHitLatency >= R:
                                        nextHitLatency = float("inf")
                                        break
                        else:
                            nextShotLatency = -1
                            nextHitLatency = -1
                            print("SHIT",sid,game,i,rows[i][47],rows[j][47])
                        events[game-1].append([rows[i][c] for c in [0, 47, 3, 4, 50, 51]] + [game,rows[i][23],nextShotLatency,nextHitLatency])
            for i in xrange(len(events[game-1])):
                events[game-1][i].append(total_shots)
        eheader = [
            "sid","eeg_time","game_time","system_time","points_raw","points_total","game","vlner_old","nextShotLatency","nextHitLatency","total_shots"
        ]
        with open(os.path.join(args.output_dir,"%s-reset-events.tsv" % sid), "wb") as fout:
            fout.write("%s\n" % ("\t".join(eheader)))
            for g in xrange(len(events)):
                for event in events[g]:
                    fout.write("%s\n" % ("\t".join(map(str,event))))
