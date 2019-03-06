#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)
if (length(args)==0) {
  stop("Error: Usage Rscript generate_plots.r <csvfile> <csvfile2> <csvfile3>", call.=FALSE)
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

vp + geom_smooth() + xlab("Time") #+ geom_smooth(data = voi_data, aes(x=nr, y=OutputVoI, color=ActiveServices)) +
        ylab("VoI") + theme_bw() + theme(text = element_text(size=15))
voict_fn_all <- paste("voi_ct_all_",gsub("[a-z _ .]", "", filename), ".png", sep="")

# save plot with all services on the same graph
ggsave(voict_fn_all, height = 5 , width = 5 * aspect_ratio)

processed_data_plot <- ggplot(voi_data, aes(x=ContentType, group=ContentType, fill=ContentType))
processed_data_plot + geom_histogram(stat="count") + facet_wrap(~Device, ncol=2) + theme(legend.position="none") +
ylab("Messages") + xlab("ContentType") + theme_bw()
processed_data_file <- paste("voi_ct_processed_",gsub("[a-z _ .]", "", filename), ".png", sep="")

ggsave(processed_data_file, height = 5 , width = 5 * aspect_ratio)

services_data <- read.csv(args[2])
services_data_plot <- ggplot(subset(services_data, Dropped %in% c("true")), aes(x=MsgContentType, group=MsgContentType, fill=MsgContentType))
services_data_plot + geom_histogram(stat="count") + facet_wrap(~Device, ncol=2) + theme_bw() + theme(legend.position="none") + ylab("Messages") + xlab("ContentType")

services_dropped_fn_all <- paste("services_dropped_all_",gsub("[a-z _ .]", "", filename), ".png", sep="")

ggsave(services_dropped_fn_all, height = 5 , width = 5 * aspect_ratio)

allocation_data <- read.csv(args[3])
allocation_data <- allocation_data[!apply(is.na(allocation_data) | allocation_data == "", 1, all),]
allocation_plot <- ggplot(allocation_data, aes(x=CurrentTime, y=CoreNumber, color=Service))
allocation_plot + geom_line() + xlab("Time") +  ylab("Allocated Cores") + facet_wrap(~Device, ncol=2)

alllocation_plot_fn <- paste("allocation_plot_file_",gsub("[a-z _ .]", "", args[3]), ".png", sep="")
ggsave(alllocation_plot_fn, height = 5 , width = 5 * aspect_ratio)

# here define another plot using ContentType as face wrap

allocation_plot <- ggplot(allocation_data, aes(x=CurrentTime, y=CoreNumber, color=Device))
allocation_plot + geom_line() + xlab("Time") +  ylab("Allocated Cores") + facet_wrap(~Service, ncol=2)

alllocation_plot_fn_2 <- paste("allocation_plot_service_file_",gsub("[a-z _ .]", "", args[3]), ".png", sep="")
ggsave(alllocation_plot_fn_2, height = 5 , width = 5 * aspect_ratio)


utilization_data <- read.csv(args[4])
utilization_data_fn <- paste("device_utilization_plot_",gsub("[a-z _ .]", "", args[3]), ".png", sep="")
utilization_plot <- ggplot(utilization_data, aes(x=CurrentTime, y=Utilization, color=Device))
utilization_plot + geom_line()  +  ylab("Allocated Cores") +  facet_wrap(~Device, ncol=2)
ggsave(utilization_data_fn, height = 5 , width = 5 * aspect_ratio)
