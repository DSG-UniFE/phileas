#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)
if (length(args)==0) {
  stop("Error: Usage Rscript generate_plots.r <csvfile> <csvfile2>", call.=FALSE)
}
# loading ggplot2 library
library(ggplot2)
library(dplyr)

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

vp + geom_smooth(data = voi_data, aes(x=nr, y=OutputVoI, color=ActiveServices)) +
        ylab("VoI") + theme_bw() + theme(text = element_text(size=15)) 
voict_fn_all <- paste("voi_ct_all_",gsub("[a-z _ .]", "", filename), ".png", sep="")

# save plot with all services on the same graph
ggsave(voict_fn_all, height = 5 , width = 5 * aspect_ratio)

# we also need to plot the mean(VoI) for each service

gd <- voi_data %>% group_by(ContentType) %>% summarise(OutputVoI = mean(OutputVoI))

gdp <- ggplot(voi_data, aes(x=ContentType, y=OutputVoI, color=ContentType)) 
gdp + geom_point() + geom_bar(data = gd, stat = "identity", alpha= .3) + guides(color = "none", fill = "none") +
xlab("Services") + ylab("VoI") + theme_bw() + theme(text = element_text(size=15)) 

voi_means <- paste("voi_means_",gsub("[a-z _ .]", "", filename), ".png", sep="")

ggsave(voi_means, height = 5 , width = 5 * aspect_ratio)

# CRIOs processed

gdp <- ggplot(voi_data, aes(ContentType)) 
gdp + geom_bar(datastat = "identity", aes(fill = ContentType)) + guides(color = "none", fill = "none") +
xlab("Services") + ylab("# CRIOs") + theme_bw() + theme(text = element_text(size=15)) 

crios <- paste("crios_",gsub("[a-z _ .]", "", filename), ".png", sep="")

ggsave(crios, height = 5 , width = 5 * aspect_ratio)

# Users distribution during the simulation time

gd <- voi_data %>% group_by(ContentType) %>% summarise(Users = mean(Users))

gdp <- ggplot(voi_data, aes(x=ContentType, y=Users, color=ContentType)) 
gdp + geom_point() + geom_bar(data = gd, stat = "identity", alpha= .3) + guides(color = "none", fill = "none") +
xlab("Services") + ylab("Users") + theme_bw() + theme(text = element_text(size=15)) 

users_mean <- paste("users_mean_",gsub("[a-z _ .]", "", filename), ".png", sep="")

ggsave(users_mean, height = 5 , width = 5 * aspect_ratio)

# Users during the time

vpu <- ggplot(voi_data, aes(x=nr, y=Users, color=ContentType))

vpu + geom_point() + facet_wrap(~ContentType, nrow=2) + #+ geom_smooth(data = voi_data, aes(x=nr, y=Users, color=ContentType)) +
        ylab("Users") + xlab("Time") + theme_bw() + theme(text = element_text(size=15), legend.position = "none") #theme(legend.position="none")

users_all <- paste("users_all_",gsub("[a-z _ .]", "", filename), ".png", sep="")

ggsave(users_all, height = 5 , width = 5 * aspect_ratio)


processed_data_plot <- ggplot(voi_data, aes(x=ContentType, group=ContentType, fill=ContentType))
processed_data_plot + geom_histogram(stat="count") + theme(legend.position="none") + ylab("Messages") + xlab("ContentType") + theme_bw()
processed_data_file <- paste("voi_ct_processed_",gsub("[a-z _ .]", "", filename), ".png", sep="")

ggsave(processed_data_file, height = 5 , width = 5 * aspect_ratio)

services_data <- read.csv(args[2])
services_data_plot <- ggplot(subset(services_data, Dropped %in% c("true")), aes(x=MsgContentType, group=MsgContentType, fill=MsgContentType))
services_data_plot + geom_histogram(stat="count") + theme_bw() + theme(legend.position="none") + ylab("Messages") + xlab("ContentType")

services_dropped_fn_all <- paste("services_ct_all_",gsub("[a-z _ .]", "", filename), ".png", sep="")

ggsave(services_dropped_fn_all, height = 5 , width = 5 * aspect_ratio)
