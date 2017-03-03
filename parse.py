#!/usr/bin/env python

"""
Parse a SF 1.5 or 1.6 logfile into something that R can load.
2/13/17: - Add suport for hexagonSizes and log format 1.6 fixes
         - Look for BDF file and inject EEG time if found
"""

import sys, os
import argparse
import csv
import glob
import mne
import math
from sf_util import *

if __name__ == '__main__':

    parser = argparse.ArgumentParser()
    parser.add_argument('subject_dir')
    parser.add_argument('output_dir')
    args = parser.parse_args()

    if os.path.isdir(args.subject_dir):
        base, sid = os.path.split(args.subject_dir)
        base, _ = os.path.split(base)

        outbase = os.path.join(args.output_dir,sid)
        if not os.path.isdir(outbase):
            os.makedirs(outbase)

        log_files = glob.glob("%s/%s-1-*.dat" % (args.subject_dir, sid))
        bdf_file = os.path.join(base,'raw_eeg','%s.bdf' % sid)
        start_times = []
        doEEG = False
        if os.path.isfile(bdf_file):
            raw = mne.io.read_raw_edf(bdf_file)
            eeg_events = mne.find_events(raw, stim_channel='STI 014', shortest_event=1)
            for e in eeg_events:
                if e[1]==0 and e[2]==1:
                    start_times.append([e[0], e[0]/raw.info["sfreq"]])
            if len(start_times) > 0 and len(start_times) != len(log_files):
                raise Exception("Number of log files does not match number of games in BDF file.")
            doEEG = True


        for log_file in log_files:
            sys.stderr.write("log file: %s\n" % log_file)
            base = os.path.splitext(log_file)[0]
            _, session, game = os.path.split(base)[1].split("-")
            sinfo = [sid, session, game]

            evt_file = "%s/%s-1-%s.evt" % (args.subject_dir, sid, game)
            ein = open(evt_file, "r")
            ext_events = {}
            with open(evt_file, "r") as ein:
                lines = [l.strip().split(" ") for l in ein.readlines()]
                N = len(lines)
                for i in xrange(N):
                    e = lines[i]
                    if len(e) == 3:
                        ext_events[int(e[0])] = e[2].split(",")

            fin = open(log_file, "r")
            version = fin.readline().strip().split(" ")
            sys.stderr.write("log version: %s\n" % version[3])
            if not version[3] in ["1.5","1.6"]:
                raise Exception("Log version %s is not supported" % (version[3]))

            if "mturk" in fin.readline().split():
                fin.readline()

            header = fin.readline().strip().replace("[",'"[').replace("]",']"')
            header = [row for row in csv.reader([header], delimiter=' ')][0][1:]
            header[3] = "ship_id"
            header[12] = "fortress_id"
            header[14] = "missiles"
            header[15] = "shells"

            pos = fin.tell()
            hexagonSizes = fin.readline().split()
            if hexagonSizes[1] == "hexagonSizes:":
                hexagonSizes = map(float,hexagonSizes[2:])
                sys.stderr.write("hexagonSizes: [%d,%d]\n" % (hexagonSizes[0],hexagonSizes[1]))
            else:
                hexagonSizes = [200, 40]
                sys.stderr.write("hexagonSizes: ![%d,%d]\n" % (hexagonSizes[0],hexagonSizes[1]))
                fin.seek(pos)

            R = len(header)
            f = fin.read().replace("[",'"[').replace("]",']"').splitlines()
            rows = []
            gs = None
            ship = [False, 0]
            fortress = [False, 0]
            thrust = [False,0]
            fire = [False,0]
            points_raw = 0
            points_total = 0
            for row in csv.reader(f, delimiter=' '):
                if row[0] == '#':
                    if row[1] in ["pnts","bonus"]:
                        continue
                    elif row[1] == "raw":
                        points_raw = int(row[3])
                        continue
                    elif row[1] == "total":
                        points_total = int(row[3])
                        continue
                    raise Exception("Unhandled comment: %s" % row)
                for i in xrange(R):
                    if i in [14,15]:
                        if row[i] != '[]': row[i] = "[%s]" %  ",".join(row[i].replace("[","").replace("]","").strip().split())
                    elif row[i] == "-":
                        row[i] = "NA"
                    else:
                        row[i] = parseCell(row[i])

                thrust_id = -1
                fire_id = -1
                if row[0] in ext_events:
                    if 'hold-thrust' in ext_events[row[2]]:
                        thrust[1] += 1
                        thrust_id = thrust[1]
                        thrust[0] = True
                    if 'hold-fire' in ext_events[row[2]]:
                        fire[1] += 1
                        fire_id = fire[1]
                        fire[0] = True

                if row[25] == "n":
                    if row[0] in ext_events and 'release-thrust' not in ext_events[row[2]]:
                        thrust_id = -1
                    thrust[0] = False
                else:
                    thrust_id = thrust[1]
                if row[28] == "n":
                    if row[0] in ext_events and 'release-fire' not in ext_events[row[2]]:
                        fire_id = -1
                    fire[0] = False
                else:
                    fire_id = fire[1]

                if gs == None:
                    gs = float(row[1])
                    if row[3] == "y":
                        ship = [True, 1]
                    if row[12] == "y":
                        fortress = [True, 1]
                else:
                    if row[3] == "y" and not ship[0]:
                        ship[1] += 1
                        ship[0] = True
                    elif row[3] == "n" and ship[0]:
                        ship[0] = False
                    if row[12] == "y" and not fortress[0]:
                        fortress[1] += 1
                        fortress[0] = True
                    elif row[12] == "n" and fortress[0]:
                        fortress[0] = False
                if ship[0]:
                    row[3] = ship[1]
                else:
                    row[3] = -1
                if fortress[0]:
                    row[12] = fortress[1]
                else:
                    row[12] = -1

                extras = [thrust_id, fire_id]
                extras += hexagonSizes
                extras += [int(hexagonSizes[0]-hexagonSizes[1])]
                extras += [round(distance(float(row[4]), float(row[5]), 355., 315.),2)]
                extras += [round(normDist(extras[-1], hexagonSizes[0], hexagonSizes[1]),3)]
                if row[3] > 0:
                    extras += [round(travel_dist_to_hex(norm(float(row[6]), float(row[7])), float(row[4]), float(row[5]), float(row[6]), float(row[7]), radius=hexagonSizes[0]),2)]
                    extras += [round(travel_dist_to_hex(norm(float(row[6]), float(row[7])), float(row[4]), float(row[5]), float(row[6]), float(row[7]), radius=hexagonSizes[1]),2)]
                    extras += [round(travel_time_to_hex(norm(float(row[6]), float(row[7])), float(row[4]), float(row[5]), float(row[6]), float(row[7]), radius=hexagonSizes[0]),3)]
                    extras += [round(travel_time_to_hex(norm(float(row[6]), float(row[7])), float(row[4]), float(row[5]), float(row[6]), float(row[7]), radius=hexagonSizes[1]),3)]
                else:
                    extras += ["NA","NA","NA","NA"]
                rows.append(sinfo + row + extras)
                if doEEG:
                    rows[-1].append(float(row[1]) - gs + float(start_times[int(game)-1][1]))
            header += ["thrust_id","fire_id","bighex_size","smallhex_size","hex_size","ship_distance","normDist","travelDist_bixhex","travelDist_smallhex","travelTime_bixhex","travelTime_smallhex"]
            if doEEG:
                header += ["eeg_time"]
            header = ["sid","session","game"] + header + ["points_raw","points_total"]
            tsv = os.path.join(outbase, "%s-%s-%s.tsv" % (sid, session, game))
            with open(tsv, "wb") as fout:
                fout.write("%s\n" % "\t".join(header))
                for row in rows:
                    fout.write("%s\n" % "\t".join(map(str,row + [points_raw,points_total])))
            sys.stderr.write("tsv file: %s\n\n" % tsv)
