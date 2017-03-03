setwd("/mnt/data/staircase/scripts")
require(data.table)
require(ggplot2)
require(RColorBrewer)
require(lme4)
require(lmerTest)

d = rbindlist(lapply(list.files("../data/processed/eeg_event_files_new",pattern="*thrust-events.tsv",full.names=TRUE), fread, header=T))[!is.nan(thrust_category)][,]
d[,pnts:=ifelse(game<=10,points_total,points_total/2)]
#d[,sid:=factor(sid,levels=sapply(1:14,function(x) paste0("subject",x)),ordered=TRUE)]
d[,sid:=factor(sid,levels=d[,.(mean_pnts=mean(pnts)),by="sid"][order(-mean_pnts)][,sid],ordered=TRUE)]
d[,thrust_category:=factor(thrust_category,levels=-2:1,labels=c("very-bad","bad","neutral","good"))]


ggplot(d) +
  geom_boxplot(aes(x=factor(game),y=tti_big_start,color=hex_size)) + 
  facet_wrap(~sid,ncol=4) + 
  scale_color_gradientn(colors=brewer.pal(3,"PuOr")[c(1,3)]) + 
  scale_x_discrete(breaks=seq(5,60,5)) + 
  theme_bw()

ggplot(d,aes(x=game,y=tti_big_start,color=hex_size)) + 
  geom_point(position="jitter",alpha=.5,size=1) + 
  facet_wrap(~sid,ncol=4) + 
  geom_smooth(method="lm",color="black") + 
  scale_color_gradientn(colors=brewer.pal(3,"PuOr")[c(1,3)]) + 
  theme_bw()

ggplot(d,aes(x=hex_size,y=tti_big_start,color=game)) + 
  geom_point(position="jitter",alpha=.5,size=1) + 
  facet_wrap(~sid,ncol=4) + 
  geom_smooth(method="lm",color="black") + 
  scale_color_gradientn(colors=brewer.pal(3,"PuOr")[c(1,3)]) + 
  theme_bw()




ggplot(d) +
  geom_boxplot(aes(x=factor(game),y=tti_big_delta,color=hex_size)) + 
  facet_wrap(~sid,ncol=4) + 
  scale_color_gradientn(colors=brewer.pal(3,"PuOr")[c(1,3)]) + 
  scale_x_discrete(breaks=seq(10,60,10)) + 
  theme_bw()

ggplot(d,aes(x=game,y=tti_big_delta,color=hex_size)) + 
  geom_point(position="jitter",alpha=.5,size=1) + 
  facet_wrap(~sid,ncol=4) + 
  geom_smooth(method="lm",color="black") + 
  scale_color_gradientn(colors=brewer.pal(3,"PuOr")[c(1,3)]) + 
  theme_bw()


ggplot(d,aes(x=hex_size,y=tti_big_delta,color=game)) + 
  geom_point(position="jitter",alpha=.5,size=1) + 
  facet_wrap(~sid,ncol=4) + 
  geom_smooth(method="lm",color="black") + 
  scale_color_gradientn(colors=brewer.pal(3,"PuOr")[c(1,3)]) + 
  theme_bw()


d.p=d[!is.infinite(tti_big_delta),.(pnts=.SD[1,pnts],hex_size=.SD[1,hex_size],mean_tti_big_delta=mean(tti_big_delta)),by=c("sid","game")]
d.c=d.p[,.(cor=cor(pnts,mean_tti_big_delta)),by="sid"]
d.v=d[!is.nan(vel_delta),.(pnts=.SD[1,pnts],hex_size=.SD[1,hex_size],vel_delta_var=var(vel_delta)),by=c("sid","game")]

d.r = d[!is.infinite(tti_big_delta),{z=coef(lm(I(tti_big_delta/hex_size)~game));.(b=z[1],m=z[2])},by=c("sid")]
ggplot(d,aes(x=game,y=tti_big_delta/hex_size)) + 
  geom_point(aes(color=hex_size),position="jitter",alpha=.25,size=.5) + 
  facet_wrap(~sid,ncol=7) + 
  geom_vline(aes(xintercept=10),linetype="dotted") +
  geom_abline(aes(slope=m,intercept=b),data=d.r,color="red") + 
  theme_bw() + ylim(0,.05) +
  geom_text(aes(x=0,y=.045,label=paste("slope=",sprintf("%.6f",round(m,6))),size=.1),data=d.r,color="red",size=3,hjust=0) +
  geom_text(aes(x=5,y=.040,label=paste("cor=",sprintf("%.3f",round(cor,3))),size=.1),data=d.c,color="blue",size=3,hjust=0) +
  scale_color_gradientn(colors=brewer.pal(3,"PuOr")[c(1,3)]) + 
  ylab("Time-to-impact Big Hex / Hex Size Difference") +
  xlab("Game Number")


td = seq(0,8,.1)
y1 = td / 60
y2 = td / 100
y3 = td / 160
z=data.table(y=c(y1,y2,y3),x=c(td,td,td),z=rep(c(60,100,160),each=length(td)))
ggplot(z) + geom_line(aes(x=x,y=y,color=factor(z),group=factor(z)))



ggplot(d[,.N,by=c("sid","game","thrust_category")]) + 
  geom_line(aes(x=game,y=N,color=thrust_category)) + 
  facet_wrap(~sid,nrow=2) + 
  theme_bw() + 
  theme(legend.position="top")