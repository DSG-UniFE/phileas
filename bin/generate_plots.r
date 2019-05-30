#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)
if (length(args)==0) {
  stop("Error: Usage Rscript generate_plots.r <csvfile> <csvfile2> <csvfile3>", call.=FALSE)
}
# loading ggplot2 library
library(ggplot2)
# for data manipulation
library(dplyr)
#set the working direcory
setwd("simulation_results")
# args[1] filename
filename <- basename(args[1])
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


# we also need to plot the mean(VoI) for each service

gd <- voi_data %>% group_by(ContentType) %>% summarise(OutputVoI = mean(OutputVoI))

gdp <- ggplot(voi_data, aes(x=ContentType, y=OutputVoI, color=ContentType)) 
gdp + geom_point() + geom_bar(data = gd, stat = "identity", alpha= .3) + guides(color = "none", fill = "none") +
xlab("Services") + ylab("VoI") + facet_wrap(~ContentType, nrow=4) + theme_bw() + 
theme(legend.position="none", text = element_text(size=10), axis.text.x=element_blank(),axis.ticks.x=element_blank()) 

voi_means <- paste("voi_means_",gsub("[a-z _ .]", "", filename), ".png", sep="")

#ggsave(voi_means, height = 5 , width = 5 * aspect_ratio)
ggsave(voi_means)

# save plot with all services on the same graph
ggsave(voict_fn_all, height = 5 , width = 5 * aspect_ratio)

processed_data_plot <- ggplot(voi_data, aes(x=ContentType, group=ContentType, fill=ContentType))
processed_data_plot + geom_histogram(stat="count") + facet_wrap(~Device, ncol=2) + theme(legend.position="none") +
ylab("CRIOs Messages") + xlab("ContentType") + theme_bw()
processed_data_file <- paste("voi_ct_processed_",gsub("[a-z _ .]", "", filename), ".png", sep="")

ggsave(processed_data_file, height = 5 , width = 5 * aspect_ratio)

# Number of dropped/discarded messages per ContentType
# This plot depicts the number of not eleaborated messages
# This plot should be the opposite of the previous one

services_data <- read.csv(basename(args[2]))
services_data_plot <- ggplot(subset(services_data, Dropped %in% c("true")), aes(x=MsgContentType, group=MsgContentType, fill=MsgContentType))
services_data_plot + geom_histogram(stat="count") + facet_wrap(~Device, ncol=2) + theme_bw() + theme(legend.position="none") +
ylab("Discarded Messages") + xlab("ContentType")

services_dropped_fn_all <- paste("services_dropped_all_",gsub("[a-z _ .]", "", filename), ".png", sep="")

ggsave(services_dropped_fn_all, height = 5 , width = 5 * aspect_ratio)

allocation_data <- read.csv(basename(args[3]))
allocation_data <- allocation_data[!apply(is.na(allocation_data) | allocation_data == "", 1, all),]

# group per Service
allocation_plot <- ggplot(allocation_data, aes(x=CurrentTime, y=CoreNumber, color=Service))
#allocation_plot + geom_line() + xlab("Time") +  ylab("Allocated Cores") + facet_wrap(~Device, ncol=1)  + theme(legend.position="bottom")
allocation_plot + geom_point(position=position_jitter(h=0.05, w=0.05),
             , alpha = 0.5, size = 1.5) + xlab("Time") +  ylab("Allocated Cores") + facet_wrap(~Device, ncol=1)  + theme(legend.position="bottom")

alllocation_plot_fn <- paste("allocation_plot_file_",gsub("[a-z _ .]", "", basename(args[3])), ".png", sep="")
ggsave(alllocation_plot_fn)

# the same as above but with geom_line() instread of coint
allocation_plot + geom_line() + xlab("Time") +  ylab("Allocated Cores") + facet_wrap(~Device, ncol=1)  + theme(legend.position="bottom")
alllocation_plot_fn <- paste("allocation_plot_line_",gsub("[a-z _ .]", "", basename(args[3])), ".png", sep="")
ggsave(alllocation_plot_fn)

# relate VoI to the number of allocated cores
cd <- allocation_data %>% group_by(Service,CurrentTime) %>% summarise(Cores = sum(CoreNumber))

cdp <- ggplot(cd, aes(x=CurrentTime, y=Cores, color=Service)) 

cdp + geom_line() + #+ guides(color = "none", fill = "none") 
xlab("Time") + ylab("Allocated Cores") + theme_bw() + theme(text = element_text(size=10)) 
cores_voi_mean_fn <- paste("total_cores_allocated_",gsub("[a-z _ .]", "", basename(args[3])), ".png", sep="")
ggsave(cores_voi_mean_fn, width=15, height=8)


#ggsave(alllocation_plot_fn, height = 5 , width = 5 * aspect_ratio)

# here define another plot using ContentType as face wrap
# remove legend theme(legend.position = "none") .

#scale_fill_discrete(guide = guide_legend()) + theme(legend.position="bottom")

# group per Device
allocation_plot <- ggplot(allocation_data, aes(x=CurrentTime, y=CoreNumber, color=Device))
#allocation_plot + geom_line() + xlab("Time") +  ylab("Allocated Cores") + facet_wrap(~Service, ncol=1) + scale_fill_discrete(guide = guide_legend()) + theme(legend.position="bottom")
allocation_plot + geom_point(position=position_jitter(h=0.05, w=0.05),
            , alpha = 0.75, size = 1.5) + xlab("Time") +  ylab("Allocated Cores") + facet_wrap(~Service, ncol=1) + scale_fill_discrete(guide = guide_legend()) + theme(legend.position="bottom")

alllocation_plot_fn_2 <- paste("allocation_plot_service_file_",gsub("[a-z _ .]", "", basename(args[3])), ".png", sep="")
#ggsave(alllocation_plot_fn_2, height = 5 , width = 5 * aspect_ratio)
ggsave(alllocation_plot_fn_2)

# the same as above but with geom_line instead of geom_poiny
allocation_plot + geom_line() + xlab("Time") +  ylab("Allocated Cores") + facet_wrap(~Service, ncol=1) + scale_fill_discrete(guide = guide_legend()) + theme(legend.position="bottom")
alllocation_plot_fn_2 <- paste("allocation_plot_service_line_",gsub("[a-z _ .]", "", basename(args[3])), ".png", sep="")
ggsave(alllocation_plot_fn_2)

utilization_data <- read.csv(basename(args[4])
utilization_data_fn <- paste("device_utilization_plot_",gsub("[a-z _ .]", "", basename(args[3])), ".png", sep="")
utilization_plot <- ggplot(utilization_data, aes(x=CurrentTime, y=Utilization, color=Device))
utilization_plot + geom_line()  +  ylab("Allocated Cores") +  facet_wrap(~Device, ncol=1) + theme(legend.position = "none")
#ggsave(utilization_data_fn, height = 5 , width = 5 * aspect_ratio)
ggsave(utilization_data_fn)


# Users distribution during the simulation time

gd <- voi_data %>% group_by(ContentType) %>% summarise(Users = mean(Users))

gdp <- ggplot(voi_data, aes(x=ContentType, y=Users, color=ContentType)) 
gdp + geom_point() + geom_bar(data = gd, stat = "identity", alpha= .3) + guides(color = "none", fill = "none") +
xlab("Services") + ylab("Users") + theme_bw() + theme(text = element_text(size=10)) 

users_mean <- paste("users_mean_",gsub("[a-z _ .]", "", filename), ".png", sep="")

ggsave(users_mean)

# Users during the time

vpu <- ggplot(voi_data, aes(x=nr, y=Users, color=ContentType))

vpu + geom_point() + facet_wrap(~ContentType, nrow=2) + #+ geom_smooth(data = voi_data, aes(x=nr, y=Users, color=ContentType)) +
        ylab("Users") + xlab("Time") + theme_bw() + theme(text = element_text(size=10), legend.position = "none") #theme(legend.position="none")

users_all <- paste("users_all_",gsub("[a-z _ .]", "", filename), ".png", sep="")

ggsave(users_all)


print("Allocation data files\n\n")

print(args[3])

print(args[4])