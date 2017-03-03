#!/usr/bin/env python

"""
Parse a SF logfile and BDF file and generate EEGLAB compat event file
"""

from __future__ import print_function, division

import sys, os
import csv
import glob
import argparse

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
            epoch = 0
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
                if not i % 30:
                    epoch += 1
                    events[game-1] += [[rows[i][47], game, epoch]]
        eheader = [
            "eeg_time","game","local_epoch","global_epoch"
        ]
        epoch = 0
        with open(os.path.join(args.output_dir,"%s-epochs.tsv" % sid), "wb") as fout:
            fout.write("%s\n" % ("\t".join(eheader)))
            for g in xrange(len(events)):
                for event in events[g]:
                    epoch += 1
                    event.append(epoch)
                    fout.write("%s\n" % ("\t".join(map(str,event))))
