require(data.table)
require(ggplot2)
setwd("D:/staircase/data")
sid = 10
d=rbindlist(lapply(1:10, function(sid) {
  d = fread(paste0("subject",sid,"/subject",sid,".ext"))
  setnames(d, c("latency","game","event","sdid","sdid_cat","game_cat","next_death","next_death_category"))
  d[,subject:=sid]
}))


normDist <- function(x,b,s) {
  x <- max(min(x,b),s)
  m = (b-s)/2
  -1 + (x-s)/m
}