setwd("/mnt/data/staircase/scripts")
require(data.table)
require(ggplot2)
require(RColorBrewer)
require(lme4)
require(lmerTest)

#' Reasons for a vlner reset:
#' 1a. Correct rule, wrong count (vlner==10)
#' 1b. Wrong rule, correct count (vlner==10)
#' 2. Trying to shoot faster (vlner==*)
#' 3. Doppler effect

d = rbindlist(lapply(list.files("../data/processed_new/eeg_event_files_new",pattern="*reset-events.tsv",full.names=TRUE), fread, header=T))
d[,pnts:=ifelse(game<=10,points_total,points_total/2)]
d[,category:=factor(ifelse(vlner_old==10,"10",ifelse(vlner_old==1,"1","2-9")),levels=c("1","2-9","10"),ordered=TRUE)]
d[,sid:=factor(sid,levels=d[,.SD[1,pnts],by=c("game","sid")][order(sid,-V1),mean(.SD[1:10,V1]),by="sid"][order(-V1)][,sid],ordered=TRUE)]

d2=d[!is.infinite(nextShotLatency) & nextShotLatency!=-1,.(meanNextShotLatency=mean(nextShotLatency/34),pnts=.SD[1,pnts]),by=c("sid","game")]

summary({m0 <- lmer(pnts~(1|sid),d2)})
summary({m1 <- lmer(pnts~game+(1|sid),d2)})
summary({m2 <- lmer(pnts~game*meanNextShotLatency+(1|sid),d2)})


.dropped = d[(nextHitLatency/34)>=2 | nextHitLatency==-1,.N]
.total = d[,.SD[1,total_shots],by=c("sid","game")][,sum(V1)]
c(.dropped, .total, round(.dropped/.total*100,2))
ggplot(d[(nextShotLatency/34)<2 & nextShotLatency!=-1]) + 
  geom_hline(aes(yintercept=.250),color="magenta",linetype="dashed") +
  geom_point(aes(x=((game-1)*60000+game_time)/60000,y=nextShotLatency/34,color=category,shape=(nextHitLatency/34)<.250)) + 
  facet_wrap(~sid,ncol=9) + 
  scale_color_manual("VLNER at Shot",values=c("blue","black","red")) +
  scale_shape_manual("Shot Triggers Reset",values=c(1,3)) +
  theme(legend.position="top") + 
  xlab("Game") + ylab("Next Shot Latency (seconds)")

.dropped = d[(nextShotLatency/34)>=2 | nextShotLatency==-1,.N]
.total = d[,.SD[1,total_shots],by=c("sid","game")][,sum(V1)]
c(.dropped, .total, round(.dropped/.total*100,2))
ggplot(d[(nextShotLatency/34)<2 & nextShotLatency!=-1]) + 
  geom_hline(aes(yintercept=.250),color="magenta",linetype="dashed") +
  geom_point(aes(x=((game-1)*60000+game_time)/60000,y=nextShotLatency/34,color=category,shape=(nextHitLatency/34)<.250)) + 
  facet_wrap(~sid,ncol=9) + 
  scale_color_manual("VLNER",values=c("blue","red","black")) +
  scale_shape_manual("Triggers Reset",values=c(1,3)) +
  theme(legend.position="top") + 
  xlab("Game") + ylab("Next Shot Latency (seconds)")

dd = d[!is.infinite(nextShotLatency) & nextShotLatency!=-1,as.data.table(table(vlner_old)),by=c("sid")]
dd = merge(dd,d[!is.infinite(nextShotLatency) & nextShotLatency!=-1,.SD[1,total_shots],by=c("sid","game")][,.(total_shots=sum(V1)),by="sid"])
dd[,vlner_old:=factor(vlner_old,levels=1:10,ordered=T)]
dd[,category:=factor(ifelse(vlner_old==10,"10",ifelse(vlner_old==1,"1","2-9")),ordered=TRUE)]
ggplot(dd) + 
  geom_bar(aes(y=N/total_shots,x=vlner_old,fill=category),stat="identity",width=.5) + 
  facet_wrap(~sid,ncol=9) + 
  scale_fill_manual("VLNER",values=c("blue","red","black")) +
  theme(legend.position="top") +
  ylab("Number of Resets / Total Number of Shots") +
  xlab("Vlner Before Reset")