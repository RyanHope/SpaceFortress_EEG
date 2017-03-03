setwd("/mnt/data/staircase/scripts")

require(h5)

chans = c(
  'Fp1','AFp1','AF7','AF3','AFF5h','AFF1h','F9','F7','F5','F3','F1','FFT9h','FFT7h','FFC5h','FFC3h','FFC1h','FT9','FT7','FC5','FC3','FC1',
  'FTT9h','FTT7h','FCC5h','FCC3h','FCC1h','T7','C5','C3','C1','TTP7h','CCP5h','CCP3h','CCP1h','TP9','TP7','CP5','CP3','CP1','CPz','TPP7h',
  'CPP5h','CPP3h','CPP1h','P9','P7','P5','P3','P1','Pz','PPO9h','PPO5h','PPO1h','PO7','PO3','POz','PO9','POO9h','O1','POO1','I1','OI1h',
  'Oz','Iz','Fpz','Fp2','AFp2','AFz','AF4','AF8','AFF2h','AFF6h','Fz','F2','F4','F6','F8','F10','FFC2h','FFC4h','FFC6h','FFT8h','FFT10h',
  'FCz','FC2','FC4','FC6','FT8','FT10','FCC2h','FCC4h','FCC6h','FTT8h','FTT10h','Cz','C2','C4','C6','T8','CCP2h','CCP4h','CCP6h','TTP8h',
  'CP2','CP4','CP6','TP8','TP10','CPP2h','CPP4h','CPP6h','TPP8h','P2','P4','P6','P8','P10','PPO2h','PPO6h','PPO10h','PO4','PO8','PO10',
  'POO2','O2','POO10h','OI2h','I2'
)

d.vlner = rbindlist(lapply(list.files("../data/processed_backup/erp",pattern="*vlner-reset.set",full.names=TRUE), function(f) {
  .set <- h5file(f,"r")
  .s <- .set["EEG/data"][]
  .d <- rbindlist(lapply(1:nrow(.s),function(e){d=as.data.table(.s[e,,]);melt(d[,c("epoch","time"):=.(e,.I)][,],id.vars=c("epoch","time"))}))
  setnames(.d, c("epoch","time","channel","value"))
  .d[,channel:=as.integer(substr(channel,2,length(channel)))]
  .d[,channel_name:=chans[channel]]
  .d[,sid:=strsplit(apply(.set["EEG/setname"][],2,intToUtf8),"-")[[1]][1]]
  .d
}))

d.vlner.occ = d.vlner[channel_name %in% c("POz","Oz"),.(value=mean(value)),by=c("time","sid")]
ggplot(d.vlner.occ) + 
  geom_line(aes(x=time/512*1000,y=value),size=1) + 
  facet_wrap(~sid) +
  scale_y_reverse() +
  xlab("Time (ms)") +
  ylab("uV") +
  scale_color_brewer("Channel",palette="Spectral") + 
  theme(panel.background=element_rect(fill=gray(.75)))






d.r = h5file("../data/processed_backup/erp_merged/vlner-reset_merged.set","r")
d.r.d = d.r['EEG/data'][]

z=rbindlist(lapply(1:nrow(d.r.d),function(e){z=as.data.table(d.r.d[e,,]);melt(z[,c("epoch","time"):=.(e,.I)][,],id.vars=c("epoch","time"))}))
setnames(z, c("epoch","time","channel","value"))
z[,channel:=as.integer(substr(channel,2,length(channel)))]
z[,channel_name:=chans[channel]]

midline = c(65, 68, 73, 84, 95, 40, 50, 56, 63, 64)
zz = z[channel %in% midline,.(value=mean(value)),by=c("time","channel","channel_name")]
zz[,grp:=ifelse(channel %in% c(73, 84, 95, 40),"B",ifelse(channel %in% c(65, 68),"A",ifelse(channel %in% c(50),"C","D")))]
zz[,channel_name:=factor(channel_name,levels=chans[midline])]
ggplot(zz) + 
  geom_vline(aes(xintercept=0),linetype="dashed") +
  geom_hline(aes(yintercept=0),linetype="dotted",size=.5) +
  geom_line(aes(x=(time/512*1000)-200,y=value,color=channel_name),size=1) + 
  scale_y_reverse() +
  facet_wrap(~grp,ncol=1) +
  xlab("Time (ms)") +
  ylab("uV") +
  scale_color_brewer("Channel",palette="Spectral") + 
  theme(panel.background=element_rect(fill=gray(.75)))