#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)
if (length(args)==0) {
  stop("Error: Usage Rscript generate_plots.r <csvfile>", call.=FALSE)
}
# loading ggplot2 library
library(ggplot2)

# args[1] filename
filename <- args[1]
voi_data <- read.csv(filename)
voi_data$nr <- as.numeric(row.names(voi_data))
vp <- ggplot(voi_data, aes(x=nr, y=OutputVoI, color=ContentType))
#vp + geom_smooth() + facet_wrap(~ContentType, nrow=4) + xlab("Time") +
#        ylab("VoI") + theme_bw() + theme(legend.position="none", text = element_text(size=15)) 
#voict_fn = paste("voi_ct_",gsub("[a-z _ .]", "", filename), ".png", sep="")
# fix plot aspect ratio
aspect_ratio <- 2.5
height <- 7

#ggsave(voict_fn,  height = 5 , width = 5 * aspect_ratio)

vp + geom_smooth() + xlab("Time") +
        ylab("VoI") + theme_bw() + theme(text = element_text(size=15)) 
voict_fn_all = paste("voi_ct_all_",gsub("[a-z _ .]", "", filename), ".png", sep="")

# save plot with all services on the same graph
ggsave(voict_fn_all, height = 5 , width = 5 * aspect_ratio)

