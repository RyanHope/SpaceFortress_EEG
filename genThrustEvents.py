#!/usr/bin/env python

"""
Parse a SF logfile and BDF file and generate EEGLAB compat event file
"""

from __future__ import print_function, division

import sys, os
import csv
import glob
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
            for i in xrange(len(rows)):
                if rows[i][6] > 0:
                    rows[i].append(np.hypot(rows[i][9],rows[i][10]))
                else:
                    rows[i].append(float("nan"))
                thrust = False
                tti_start_big = None
                tti_start_small = None
                tti_end_big = None
                tti_end_small = None
                vel_start = None
                vel_end = None
                if rows[i][36] > 0:
                    if i == 0:
                        thrust = True
                        tti_start_big = rows[i][45]
                        tti_start_small = rows[i][46]
                        vel_start = rows[i][50]
                    elif rows[i-1][36] != rows[i][36]:
                        thrust = True
                        tti_start_big = rows[i-1][45]
                        tti_start_small = rows[i-1][46]
                        vel_start = rows[i-1][50]
                if thrust:
                    j = 0
                    while rows[i][28] == "y":
                        j += 1
                        if i+j < R:
                            if rows[i+j][36] != rows[i][36]:
                                if rows[i+j][36] == "NA":
                                    j -= 1
                            break
                        else:
                            break
                    events[game-1].append([rows[i][c] for c in [0, 47, 3, 4, 6, 36, 40, 42, 48, 49]] + [j])
                    if rows[i][6] > 0:
                        #print(rows[i])
                        tti_end_big = rows[i+j-1][45]
                        tti_end_small = rows[i+j-1][46]
                        vel_end = rows[i+j-1][50]
                        vel_delta = round(vel_end-vel_start,3)
                        if tti_end_big == float("inf") and tti_start_big == float("inf"):
                            tti_big_delta = 0
                        else:
                            tti_big_delta = round(tti_end_big-tti_start_big,3)
                        if tti_end_small == float("inf") and tti_start_small == float("inf"):
                            tti_small_delta = 0
                        else:
                            tti_small_delta = round(tti_end_small-tti_start_small,3)
                        thrust_category = -2#"very-bad"
                        if tti_small_delta == 0:
                            if tti_big_delta > 0:
                                thrust_category = 1#"good"
                            elif tti_big_delta == 0:
                                thrust_category = 0#"neutral"
                            elif tti_big_delta < 0:
                                thrust_category = -1#"bad"
                        events[game-1][-1] += [
                            tti_start_big, tti_big_delta,
                            tti_start_small, tti_small_delta,
                            thrust_category, vel_delta
                        ]
                    else:
                        events[game-1][-1] += [float("nan")] * 6
                    events[game-1][-1] = events[game-1][-1][0:4] + ['thrust', game] + events[game-1][-1][4:]
        eheader = [
            "sid","eeg_time","game_time","system_time","event","game","ship_id","thrust_id",
            "hex_size","distNorm","points_raw","points_total","duration","tti_big_start",
            "tti_big_delta","tti_small_start","tti_small_delta","thrust_category","vel_delta"
        ]
        with open(os.path.join(args.output_dir,"%s-thrust-events.tsv" % sid), "wb") as fout:
            fout.write("%s\n" % ("\t".join(eheader)))
            for g in xrange(len(events)):
                for event in events[g]:
                    fout.write("%s\n" % ("\t".join(map(str,event))))
