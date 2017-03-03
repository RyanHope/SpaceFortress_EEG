setwd("/mnt/data/staircase/scripts")
require(data.table)
require(ggplot2)
require(RColorBrewer)
require(lme4)
require(lmerTest)

d = rbindlist(lapply(list.files("../data/processed/eeg_event_files_new",pattern="*vlner-events.tsv",full.names=TRUE), fread, header=T))