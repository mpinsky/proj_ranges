# Set up a Marxan with Zones run for CMSP

## Set working directories
if(Sys.info()["nodename"] == "pinsky-macbookair"){
	setwd('~/Documents/Rutgers/Range projections/proj_ranges/')
	marxfolder <- '../MarZone_runs/'
	presmapbymodfolder <- '../data/'
	}
if(Sys.info()["nodename"] == "amphiprion.deenr.rutgers.edu"){
	setwd('~/Documents/range_projections/')
	.libPaths(new='~/R/x86_64-redhat-linux-gnu-library/3.1/') # so that it can find my old packages
	marxfolder <- 'MarZone_runs/'
	presmapbymodfolder <- 'data/'
	}
# could add code for Lauren's working directory here


############
## Flags
############

## choose which runs to use
## runtype refers to how the Species Distribution Models (SDMs) were fit
## projtype refers to how the SDM projections were done
#runtype <- 'test'; projtype=''
#runtype <- ''; projtype=''`
#runtype <- 'testK6noSeas'; projtype='_xreg'
runtype <- 'fitallreg'; projtype='_xreg'

# choose the rcps (get to choose two)
rcp <- 85
otherrcp <- 45

# CMSP goals
consgoal <- 0.1 # proportion of presences to capture in conservation
energygoal <- 0.2 # proportion of NPV
fishgoal <- 0.5 # proportion of biomass
conscolnm <- 'proppres'
fishcolnm <- 'proppres' # which column to use for fish goal (pres = occurrences, propwtcpue = biomass)

# choose regions and names for these runs (for reading in)
myregs <- c('NEFSC_NEUSSpring', 'AFSC_EBS', 'DFO_NewfoundlandFall', 'SEFSC_GOMex', 'DFO_ScotianShelf', 'DFO_SoGulf', 'AFSC_GOA', 'AFSC_Aleutians', 'NWFSC_WCAnn')
runname1s <- c('cmsphistonly_neus', 'cmsphistonly_ebs', 'cmsphistonly_newf', 'cmsphistonly_gmex', 'cmsphistonly_scot', 'cmsphistonly_sgulf', 'cmsphistonly_goa', 'cmsphistonly_ai', 'cmsphistonly_wc')
runname2s <- c('cmsp2per_neus', 'cmsp2per_ebs', 'cmsp2per_newf', 'cmsp2per_gmex', 'cmsp2per_scot', 'cmsp2per_sgulf', 'cmsp2per_goa', 'cmsp2per_ai', 'cmsp2per_wc')

# choose names for writing out
runname1out <- 'cmsphistonly_all'
runname2out <- 'cmsp2per_all'

# check
length(myregs) == length(runname1s)
length(myregs) == length(runname2s)

# folders
inputfolder1s <- paste(marxfolder, runname1s, '_input', sep='')
inputfolder2s <- paste(marxfolder, runname2s, '_input', sep='')
outputfolder1s <- paste(marxfolder, runname1s, '_output', sep='')
outputfolder2s <- paste(marxfolder, runname2s, '_output', sep='')

######################
## Helper functions
######################
require(RColorBrewer)
require(data.table)
require(maps)


###############################################
# Make table to fishery species in each region
###############################################
fsppsused <- data.frame(region=character(0), spp=character(0))

for(i in 1:length(myregs)){
	spec <- read.csv(paste(inputfolder1s[i], '/spec.dat', sep=''))
	targ <- read.csv(paste(inputfolder1s[i], '/zonetarget.dat', sep=''))
	
	temp <- data.frame(region=myregs[i], spp=spec$name[spec$id %in% targ$speciesid[targ$zoneid==3]])
	
	fsppsused <- rbind(fsppsused, temp)
}

write.csv(fsppsused, file='cmsp_data/fisheryspps_used.csv')

#######################################################
# Read in results and simple prep
#######################################################
consplan1s <- vector('list', length(runname1s))
for(i in 1:length(consplan1s)) consplan1s[[i]] <- read.csv(paste(outputfolder1s[i], '/', runname1s[i], '_best.csv', sep=''))
consplan2s <- vector('list', length(runname2s))
for(i in 1:length(consplan2s)) consplan2s[[i]] <- read.csv(paste(outputfolder2s[i], '/', runname2s[i], '_best.csv', sep=''))

# add zone to pus
pusplan1s <- vector('list', length(runname1s))
pusplan2s <- vector('list', length(runname2s))
for(i in 1:length(inputfolder1s)){
	load(paste(inputfolder1s[i], '/pus.Rdata', sep='')) # pus
	load(paste(inputfolder2s[i], '/pus.Rdata', sep='')) # pus2

	pusplan1s[[i]] <- merge(pus, consplan1s[[i]], by.x='id', by.y='planning_unit')
		dim(pus)
		dim(pusplan1s[[i]])
		table(pusplan1s[[i]]$zone)

	pusplan2s[[i]] <- merge(pus2, consplan2s[[i]], by.x='id', by.y='planning_unit')
		dim(pus2)
		dim(pusplan2s[[i]])
		table(pusplan2s[[i]]$zone)
}
names(pusplan1s) <- myregs
names(pusplan2s) <- myregs

# load the species lists
sppslist <- vector('list', length(runname1s))
spps2list <- vector('list', length(runname2s))
for(i in 1:length(inputfolder1s)){
	load(paste(inputfolder1s[[i]], '/spps.Rdata', sep='')) # spps
	load(paste(inputfolder2s[[i]], '/spps.Rdata', sep='')) # spps2
	
	sppslist[[i]] <- spps
	spps2list[[i]] <- spps2
}

fisheryspps <- read.csv('cmsp_data/fishery_spps.csv', row.names=1) # which spp to include in fishery goal in each region

#load(paste('data/rich_', runtype, projtype, '_rcp', rcp, '.RData', sep='')) # loads rich data.frame with presence/absence information
#load(paste('data/presmap_', runtype, projtype, '_rcp', rcp, '.RData', sep='')) # loads presmap data.frame with presence/absence information for ensemble mean

# load all model runs... slow
# better to run this on Amphiprion: takes 20 GB memory
load(paste(presmapbymodfolder, 'presmapbymod_', runtype, projtype, '_rcp', rcp, '.RData', sep='')) # loads presmap data.frame with presence/absence information from each model (slow to load).
	presmapbymod.1 <- as.data.table(presmapbymod)
	rm(presmapbymod)
	presmapbymod.1[,rcp:=rcp]
	dim(presmapbymod.1)
load(paste(presmapbymodfolder, 'presmapbymod_', runtype, projtype, '_rcp', otherrcp, '.RData', sep='')) # loads presmap data.frame with presence/absence information from each model (slow to load) (for the other rcp, the one not used for planning)
	presmapbymod.2 <- as.data.table(presmapbymod)
	rm(presmapbymod)
	presmapbymod.2[,rcp:=otherrcp]
	dim(presmapbymod.2)
	presmapbymod <- rbind(presmapbymod.1, presmapbymod.2, use.names=TRUE)
	tables()
	rm(presmapbymod.1)
	rm(presmapbymod.2)



####################################################################################
## Basic maps of solutions
## NOTE: commented out parts were written assuming only one region. needs updating
####################################################################################

# plot map of selected grids, on top of richness (consplan #1)
#	colfun <- colorRamp(rev(brewer.pal(11, 'Spectral')))
#	cexs = 1 # to adjust
#	periods <- sort(unique(rich$period))
#	# quartz(width=20, height=5)
#	pdf(width=20, height=5, file=paste('cmsp_figures/MarZone_', myreg, '_on_richness_', runname1, '_', runtype, projtype, '_rcp', rcp, '.pdf', sep=''))
#	par(mfrow=c(1,length(periods)), mai=c(0.5,0.5,0.3, 0.1), las=1, mgp=c(2,1,0))
#	j <- rich$region == 'NEFSC_NEUSSpring'
#	for(i in 1:length(periods)){
#		j2 <- rich$period == periods[i] & j
#		plot(rich$lon[j2], rich$lat[j2], col=rgb(colfun(pnorm01(rich$rich[j2], rich$rich[j])), maxColorValue=255), pch=16, cex=cexs, xlab='Longitude', ylab='Latitude', main=paste(myreg, periods[i]), cex.main=0.9)
#
#		i <- pusplan1$zone == 2
#		points(pusplan1$lon[i], pusplan1$lat[i], pch=1, col='black', cex=cexs) # conservation
#
#		i <- pusplan1$zone == 3
#		points(pusplan1$lon[i], pusplan1$lat[i], pch=1, col='blue', cex=cexs) # fishery
#
#		i <- pusplan1$zone == 4
#		points(pusplan1$lon[i], pusplan1$lat[i], pch=1, col='purple', cex=cexs) # energy
#	}
#	legend('bottomright', legend=c(round(seq(min(rich$rich[j]), max(rich$rich[j]), length.out=10),2), 'Conservation', 'Fishery', 'Energy'), col=c(rgb(colfun(norm01(seq(min(rich$rich[j]), max(rich$rich[j]), length.out=10))), maxColorValue=255), 'black', 'blue', 'purple'), pch=c(rep(16,10), rep(1,3)), cex=0.7, title='Species', bty='n')
#
#
#	dev.off()

# plot map of selected grids, on top of richness (consplan #1 and #2)
#	colfun <- colorRamp(rev(brewer.pal(11, 'Spectral')))
#	cexs = 1 # to adjust
#	periods <- sort(unique(rich$period))
#	# quartz(width=20, height=10)
#	pdf(width=20, height=10, file=paste('cmsp_figures/MarZone_', myreg, '_on_richness_', runname1, '&', runname2, '_', runtype, projtype, '_rcp', rcp, '.pdf', sep=''))
#	par(mfrow=c(2,length(periods)), mai=c(0.5,0.5,0.3, 0.1), las=1, mgp=c(2,1,0))
#	j <- rich$region == myreg
#	for(i in 1:length(periods)){ # for plan1
#		j2 <- rich$period == periods[i] & j
#		plot(rich$lon[j2], rich$lat[j2], col=rgb(colfun(pnorm01(rich$rich[j2], rich$rich[j])), maxColorValue=255), pch=16, cex=cexs, xlab='Longitude', ylab='Latitude', main=paste(myreg, periods[i]), cex.main=0.9)
#
#		i <- pusplan1$zone == 2
#		points(pusplan1$lon[i], pusplan1$lat[i], pch=1, col='black', cex=cexs) # conservation
#
#		i <- pusplan1$zone == 3
#		points(pusplan1$lon[i], pusplan1$lat[i], pch=1, col='blue', cex=cexs) # fishery
#
#		i <- pusplan1$zone == 4
#		points(pusplan1$lon[i], pusplan1$lat[i], pch=1, col='purple', cex=cexs) # energy
#	}
#	for(i in 1:length(periods)){ # for plan2
#		j2 <- rich$period == periods[i] & j
#		plot(rich$lon[j2], rich$lat[j2], col=rgb(colfun(pnorm01(rich$rich[j2], rich$rich[j])), maxColorValue=255), pch=16, cex=cexs, xlab='Longitude', ylab='Latitude', main=paste(myreg, periods[i]), cex.main=0.9)
#
#		i <- pusplan2$zone == 2
#		points(pusplan2$lon[i], pusplan2$lat[i], pch=1, col='black', cex=cexs) # conservation
#
#		i <- pusplan2$zone == 3
#		points(pusplan2$lon[i], pusplan2$lat[i], pch=1, col='blue', cex=cexs) # fishery
#
#		i <- pusplan2$zone == 4
#		points(pusplan2$lon[i], pusplan2$lat[i], pch=1, col='purple', cex=cexs) # energy
#	}
#	legend('bottomright', legend=c(round(seq(min(rich$rich[j]), max(rich$rich[j]), length.out=10),2), 'Conservation', 'Fishery', 'Energy'), col=c(rgb(colfun(norm01(seq(min(rich$rich[j]), max(rich$rich[j]), length.out=10))), maxColorValue=255), 'black', 'blue', 'purple'), pch=c(rep(16,10), rep(1,3)), cex=0.7, title='Species', bty='n')
#
#
#	dev.off()
	
	
# plot map of selected grids (consplan #1 and #2)
cexs = 0.5 # to adjust
periods <- sort(unique(rich$period))
# quartz(width=5, height=18)
pdf(width=5, height=18, file=paste('cmsp_figures/Planmaps_', runtype, projtype, '_rcp', rcp, '.pdf', sep=''))
par(mfrow=c(9,2), mai=c(0.5,0.5,0.3, 0.1), las=1, mgp=c(2,1,0))
for(i in 1:length(pusplan1s)){
	j <- pusplan1s[[i]]$zone == 2
	plot(pusplan1s[[i]]$lon[j], pusplan1s[[i]]$lat[j], pch=16, col='red', cex=cexs, main='Historical only', xlab='', ylab='') # conservation
	j <- pusplan1s[[i]]$zone == 3
	points(pusplan1s[[i]]$lon[j], pusplan1s[[i]]$lat[j], pch=16, col='blue', cex=cexs) # fishery
#	i <- pusplan1s[[i]]$zone == 4
#	points(pusplan1$lon[i], pusplan1$lat[i], pch=16, col='red', cex=cexs) # energy

	j <- pusplan2s[[i]]$zone == 2
	plot(pusplan2s[[i]]$lon[j], pusplan2s[[i]]$lat[j], pch=16, col='red', cex=cexs, main='Two periods', xlab='', ylab='') # conservation
	j <- pusplan2s[[i]]$zone == 3
	points(pusplan2s[[i]]$lon[j], pusplan2s[[i]]$lat[j], pch=16, col='blue', cex=cexs) # fishery
#	i <- pusplan2$zone == 4
#	points(pusplan2$lon[i], pusplan2$lat[i], pch=16, col='red', cex=cexs) # energy
}

legend('topright', legend=c('Conservation', 'Fishery', 'Energy'), col=c('red', 'blue', 'purple'), pch=rep(16,3), cex=0.7, title='Zones', bty='n')


dev.off()


############################
## Basic stats on the plans
############################
# have to read in the plans above (but don't need to read in the species distributions)
climGrid <- read.csv('data/climGrid.csv', row.names=1) # for temperature climatology and depth

# latitudinal range by zone in each plan
# do 2per plans span a wider latitudinal range?
#	a <- lapply(pusplan1s, FUN=function(x) aggregate(list(latrng_histonly=x$lat), by=list(zone=x$zone), FUN=function(x) max(x)-min(x)))
#	b <- lapply(pusplan2s, FUN=function(x) aggregate(list(latrng_2per=x$lat), by=list(zone=x$zone), FUN=function(x) max(x)-min(x)))
	a <- lapply(pusplan1s, FUN=function(x) aggregate(list(latsd_histonly=x$lat), by=list(zone=x$zone), FUN=function(x) sd(x)))
	b <- lapply(pusplan2s, FUN=function(x) aggregate(list(latsd_2per=x$lat), by=list(zone=x$zone), FUN=function(x) sd(x)))
	a <- do.call('rbind',a)
	b <- do.call('rbind',b)
	a$reg <- gsub('.[[:digit:]]', '', row.names(a))
	b$reg <- gsub('.[[:digit:]]', '', row.names(b))
	d <- merge(a,b)
	d[d$zone==2,] # conservation
	d[d$zone==3,] # fishing
	d$diff <- d$latrng_2per - d$latrng_histonly # positive if 2per spans a wider range
	summary(d$diff)
	wilcox.test(d$diff[d$zone==2])
	wilcox.test(d$diff[d$zone==3])
		# note: zone 1 available, 2 conservation, 3 fishery, 4 energy
	
# temperature and depth range by zone in each plan
	# add in climatology temperature
pusplan1swclim <- pusplan1s
pusplan2swclim <- pusplan2s
for(i in 1:length(pusplan1swclim)){
	pusplan1swclim[[i]] <- merge(pusplan1s[[i]], climGrid[,c('lat', 'lon', 'bottemp.clim.int', 'surftemp.clim.int', 'depth')], all.x=TRUE)
	pusplan2swclim[[i]] <- merge(pusplan2s[[i]], climGrid[,c('lat', 'lon', 'bottemp.clim.int', 'surftemp.clim.int', 'depth')], all.x=TRUE)
}

	# do 2per plans span a wider surface temperature range?
#	a <- lapply(pusplan1swclim, FUN=function(x) aggregate(list(temprng_histonly=x$surftemp.clim.int), by=list(zone=x$zone), FUN=function(x) max(x, na.rm=TRUE)-min(x, na.rm=TRUE)))
#	b <- lapply(pusplan2swclim, FUN=function(x) aggregate(list(temprng_2per=x$surftemp.clim.int), by=list(zone=x$zone), FUN=function(x) max(x, na.rm=TRUE)-min(x, na.rm=TRUE)))
	a <- lapply(pusplan1swclim, FUN=function(x) aggregate(list(tempsd_histonly=x$surftemp.clim.int), by=list(zone=x$zone), FUN=function(x) sd(x, na.rm=TRUE)))
	b <- lapply(pusplan2swclim, FUN=function(x) aggregate(list(tempsd_2per=x$surftemp.clim.int), by=list(zone=x$zone), FUN=function(x) sd(x, na.rm=TRUE)))
	a <- do.call('rbind',a)
	b <- do.call('rbind',b)
	a$reg <- gsub('.[[:digit:]]', '', row.names(a))
	b$reg <- gsub('.[[:digit:]]', '', row.names(b))
	d <- merge(a,b)
	d[d$zone==2,] # conservation
	d[d$zone==3,] # fishing
	d$diff <- d$temprng_2per - d$temprng_histonly # positive if 2per spans a wider range
	summary(d$diff)
	wilcox.test(d$diff[d$zone==2])
	wilcox.test(d$diff[d$zone==3])

	# do 2per plans span a wider bottom temperature range?
#	a <- lapply(pusplan1swclim, FUN=function(x) aggregate(list(temprng_histonly=x$bottemp.clim.int), by=list(zone=x$zone), FUN=function(x) max(x, na.rm=TRUE)-min(x, na.rm=TRUE)))
#	b <- lapply(pusplan2swclim, FUN=function(x) aggregate(list(temprng_2per=x$bottemp.clim.int), by=list(zone=x$zone), FUN=function(x) max(x, na.rm=TRUE)-min(x, na.rm=TRUE)))
	a <- lapply(pusplan1swclim, FUN=function(x) aggregate(list(tempsd_histonly=x$bottemp.clim.int), by=list(zone=x$zone), FUN=function(x) sd(x, na.rm=TRUE)))
	b <- lapply(pusplan2swclim, FUN=function(x) aggregate(list(tempsd_2per=x$bottemp.clim.int), by=list(zone=x$zone), FUN=function(x) sd(x, na.rm=TRUE)))
	a <- do.call('rbind',a)
	b <- do.call('rbind',b)
	a$reg <- gsub('.[[:digit:]]', '', row.names(a))
	b$reg <- gsub('.[[:digit:]]', '', row.names(b))
	d <- merge(a,b)
	d[d$zone==2,] # conservation
	d[d$zone==3,] # fishing
	d$diff <- d$temprng_2per - d$temprng_histonly # positive if 2per spans a wider range
	summary(d$diff)
	wilcox.test(d$diff[d$zone==2])
	wilcox.test(d$diff[d$zone==3])


	# do 2per plans span a wider depth range?
	a <- lapply(pusplan1swclim, FUN=function(x) aggregate(list(depthrng_histonly=x$depth), by=list(zone=x$zone), FUN=function(x) max(x, na.rm=TRUE)-min(x, na.rm=TRUE)))
	b <- lapply(pusplan2swclim, FUN=function(x) aggregate(list(depthrng_2per=x$depth), by=list(zone=x$zone), FUN=function(x) max(x, na.rm=TRUE)-min(x, na.rm=TRUE)))
	a <- do.call('rbind',a)
	b <- do.call('rbind',b)
	a$reg <- gsub('.[[:digit:]]', '', row.names(a))
	b$reg <- gsub('.[[:digit:]]', '', row.names(b))
	d <- merge(a,b)
	d[d$zone==2,] # conservation
	d[d$zone==3,] # fishing
	d$diff <- d$temprng_2per - d$temprng_histonly # positive if 2per spans a wider range
	summary(d$diff)
	wilcox.test(d$diff[d$zone==2])
	wilcox.test(d$diff[d$zone==3])

######################################################################
# Analyze against each climate model projection                      #
# across each rcp                                                    #
######################################################################

abundbyzonebymod1 <- vector('list', length(myregs))
abundbyzonebymod2 <- vector('list', length(myregs))
goalsmetbymod1 <- vector('list', length(myregs))
goalsmetbymod2 <- vector('list', length(myregs))

setkey(presmapbymod, region)

models <- sort(unique(presmapbymod$model))
periods <- sort(unique(presmapbymod$period))

# takes 25G memory and 10 min on MacBook Air
for(i in 1:length(myregs)){
	print(i)
	
	finds <- fisheryspps$region == myregs[i] # trim to this region

	# evaluate # targets met in each time period in each model
		# calculate total presences and wtcpue by species and time-period
		totals <- expand.grid(sppocean=sppslist[[i]]$sppocean[sppslist[[i]]$name != 'energy'], period=periods, model=models, rcp=c(rcp, otherrcp)) # grid of all spp and time periods and models and rcps
			dim(totals)
		
		totcalcs <- aggregate(list(totalpres = presmapbymod[myregs[i],pres], totalwtcpue=presmapbymod[myregs[i],wtcpue.proj]), by=list(sppocean=presmapbymod[myregs[i],sppocean], period=presmapbymod[myregs[i],period], model=presmapbymod[myregs[i],model], rcp=presmapbymod[myregs[i],rcp]), FUN=sum) # how many spp presences and amount in each period in each model for focal rcp
			dim(totcalcs)

		totals2 <- merge(totals, totcalcs, all.x=TRUE) # make sure all spp and time periods and models and rcps represented
		totals2$totalpres[is.na(totals2$totalpres)] <- 0
		totals2$totalwtcpue[is.na(totals2$totalwtcpue)] <- 0
		totals2$zone <- 2 # for conservation

		# add totals for the fishery zones
		temp <- totals2
		temp$zone <- 3
		temp <- temp[temp$sppocean %in% fisheryspps$projname[finds],]
			nrow(temp)/5/13/2 # 8 species: good
		totals2 <- as.data.table(rbind(totals2, temp)) # for fishery

			length(unique(totals2$sppocean)) # number of species: 67
			numgoals <- length(unique(paste(totals2$sppocean, totals2$zone))) # number of goals: 75
				numgoals
			nrow(totals2)

		# merge plan zones into presmap
		temp1 <- merge(presmapbymod[myregs[i], ], pusplan1s[[i]][pusplan1s[[i]]$zone %in% c(2,3),], by=c('lat', 'lon')) # only keep the conserved & fishery zones for goals
			dim(temp1) # a data.table
		temp2 <- merge(presmapbymod[myregs[i], ], pusplan2s[[i]][pusplan2s[[i]]$zone %in% c(2,3),], by=c('lat', 'lon'))
		abundbyzone1 <- temp1[,.(npres=sum(pres),sumwtcpue=sum(wtcpue.proj)),by=c('sppocean','period','zone','model','rcp')]
			dim(abundbyzone1) # 67080
		abundbyzone2 <- temp2[,.(npres=sum(pres),sumwtcpue=sum(wtcpue.proj)),by=c('sppocean','period','zone','model','rcp')]
			dim(abundbyzone2) # 67080

		# add totals for pres and wtcpue across all zones
		# intersect(names(abundbyzone1), names(totals2))
		setkey(totals2, sppocean,period,model,rcp,zone)
		setkey(abundbyzone1, sppocean,period,model,rcp,zone)
		setkey(abundbyzone2, sppocean,period,model,rcp,zone)
		abundbyzonebymod1[[i]] <- merge(abundbyzone1, totals2, all.y=TRUE)
			if(abundbyzonebymod1[[i]][,sum(is.na(npres))]>0) abundbyzonebymod1[[i]][is.na(npres),npres:=0]
			if(abundbyzonebymod1[[i]][,sum(is.na(sumwtcpue))]>0) abundbyzonebymod1[[i]][is.na(sumwtcpue),sumwtcpue:=0]
			dim(abundbyzonebymod1[[i]]) # 9750
			abundbyzonebymod1[[i]][,length(unique(sppocean))] # 67 species
			abundbyzonebymod1[[i]][,sort(table(as.character(sppocean)))] # entries per species, from low to high. 8 species appear in both conservation and fishery zones.
		abundbyzonebymod2[[i]] <- merge(abundbyzone2, totals2, all.y=TRUE)
			if(abundbyzonebymod2[[i]][,sum(is.na(npres))]>0) abundbyzonebymod2[[i]][is.na(npres),npres:=0]
			if(abundbyzonebymod2[[i]][,sum(is.na(sumwtcpue))]>0) abundbyzonebymod2[[i]][is.na(sumwtcpue),sumwtcpue:=0]
			dim(abundbyzonebymod2[[i]]) # 9750
			abundbyzonebymod2[[i]][,length(unique(sppocean))] # 67 species
			abundbyzonebymod2[[i]][,sort(table(as.character(sppocean)))] # entries per species, from low to high. 8 species appear in both 
		# calculate proportion of presences and wtcpue
		abundbyzonebymod1[[i]][,proppres:=npres/totalpres]
		abundbyzonebymod2[[i]][,proppres:=npres/totalpres]
		abundbyzonebymod1[[i]][,propwtcpue:=sumwtcpue/totalwtcpue]
		abundbyzonebymod2[[i]][,propwtcpue:=sumwtcpue/totalwtcpue]

		# force 0/0 to 1 so that it counts as a goal met
		abundbyzonebymod1[[i]][npres==0 & totalpres==0,proppres:=1]
		abundbyzonebymod2[[i]][npres==0 & totalpres==0,proppres:=1]
		abundbyzonebymod1[[i]][sumwtcpue==0 & totalwtcpue==0,propwtcpue:=1]
		abundbyzonebymod2[[i]][sumwtcpue==0 & totalwtcpue==0,propwtcpue:=1]
	
		# mark where goals met for conservation or fishery
		abundbyzonebymod1[[i]][,metgoal:=FALSE]
		abundbyzonebymod2[[i]][,metgoal:=FALSE]
		expr <- paste('zone==2 &', conscolnm, '>=', consgoal) # the only way to dynamically construct a vector with which to choose rows (http://r.789695.n4.nabble.com/Idiomatic-way-of-using-expression-in-i-td4711229.html)
		abundbyzonebymod1[[i]][eval(parse(text=expr)),metgoal:=TRUE]
		abundbyzonebymod2[[i]][eval(parse(text=expr)),metgoal:=TRUE]
		expr2 <- paste('zone==3 &', fishcolnm, '>=', fishgoal)
		abundbyzonebymod1[[i]][eval(parse(text=expr2)),metgoal:=TRUE]
		abundbyzonebymod2[[i]][eval(parse(text=expr2)),metgoal:=TRUE]


		# calculate number goals met in each timeperiod
		goalsmetbymod1[[i]] <- abundbyzonebymod1[[i]][,.(nmet=sum(metgoal)),by=c('period','model','rcp')]
		goalsmetbymod1[[i]]$mid <- sapply(strsplit(as.character(goalsmetbymod1[[i]]$period), split='-'), FUN=function(x) mean(as.numeric(x)))
		goalsmetbymod1[[i]]$pmet <- goalsmetbymod1[[i]]$nmet/numgoals

		goalsmetbymod2[[i]] <- abundbyzonebymod2[[i]][,.(nmet=sum(metgoal)),by=c('period','model','rcp')]
		goalsmetbymod2[[i]]$mid <- sapply(strsplit(as.character(goalsmetbymod2[[i]]$period), split='-'), FUN=function(x) mean(as.numeric(x)))
		goalsmetbymod2[[i]]$pmet <- goalsmetbymod2[[i]]$nmet/numgoals

		# set region
		abundbyzonebymod1[[i]][,region:=myregs[i]]
		abundbyzonebymod2[[i]][,region:=myregs[i]]
		goalsmetbymod1[[i]][,region:=myregs[i]]
		goalsmetbymod2[[i]][,region:=myregs[i]]
}

# clean up
rm(temp1)
rm(temp2)

# flatten lists into data.frames
abundbyzonebymod1out <- rbindlist(abundbyzonebymod1)
abundbyzonebymod2out <- rbindlist(abundbyzonebymod2)
goalsmetbymod1out <- rbindlist(goalsmetbymod1)
goalsmetbymod2out <- rbindlist(goalsmetbymod2)

dim(abundbyzonebymod1out)
dim(abundbyzonebymod2out)
dim(goalsmetbymod1out)
dim(goalsmetbymod2out)

# write out
write.csv(abundbyzonebymod1out, file=paste('output/abundbyzonebymod_', runtype, projtype, '_', runname1out, '.csv', sep=''))
write.csv(abundbyzonebymod2out, file=paste('output/abundbyzonebymod_', runtype, projtype, '_', runname2out, '.csv', sep=''))
write.csv(goalsmetbymod1out, file=paste('output/goalsmetbymod_', runtype, projtype, '_', runname1out, '.csv', sep=''))
write.csv(goalsmetbymod2out, file=paste('output/goalsmetbymod_', runtype, projtype, '_', runname2out, '.csv', sep=''))


######################################################################
# Compare and plot the planning approaches against all climate models
######################################################################
goalsmetbymod1out <- read.csv(paste('output/goalsmetbymod_', runtype, projtype, '_', runname1out, '.csv', sep=''), row.names=1)
goalsmetbymod2out <- read.csv(paste('output/goalsmetbymod_', runtype, projtype, '_', runname2out, '.csv', sep=''), row.names=1)


myregs <- c('AFSC_Aleutians', 'AFSC_EBS', 'AFSC_GOA', 'DFO_NewfoundlandFall', 'DFO_ScotianShelf', 'DFO_SoGulf', 'NEFSC_NEUSSpring', 'SEFSC_GOMex')
mods <- sort(unique(goalsmetbymod1out$model))
rcps <- sort(unique(goalsmetbymod1out$rcp))
regnames<-c('Aleutians Is.', 'E. Bering Sea', 'Gulf of AK', 'Newfoundland', 'Scotian Shelf', 'S. Gulf of St. Lawrence', 'Northeast US')

# add plan identifier
goalsmetbymod1out$plan <- 'histonly'
goalsmetbymod2out$plan <- '2per'

# combine
goalsmetbymod <- rbind(goalsmetbymod1out, goalsmetbymod2out)


# compare goals met across plans and time periods
	goalmetbymodag <- with(rbind(goalsmetbymod1out, goalsmetbymod2out), aggregate(list(pmet=pmet), by=list(plan=plan, model=model, rcp=rcp, period=period), FUN=mean))
	with(goalmetbymodag, aggregate(list(ave_goals=pmet), by=list(plan=plan, period=period), FUN=mean))
	with(goalmetbymodag, aggregate(list(ave_goals=pmet), by=list(plan=plan, period=period), FUN=se))
	with(goalmetbymodag, aggregate(list(ave_goals=pmet), by=list(plan=plan, period=period), FUN=length))


# test whether histonly meets significantly fewer goals than 2per
	all(goalsmetbymod1out$model == goalsmetbymod2out$model & goalsmetbymod1out$period == goalsmetbymod2out$period & goalsmetbymod1out$rcp == goalsmetbymod2out$rcp) # same order?

	# simple t-test on number met (pseudoreplicates within regions)
	t.test(goalsmetbymod1out$nmet[goalsmetbymod1out$period=='2081-2100'], goalsmetbymod2out$nmet[goalsmetbymod2out$period=='2081-2100'])

	# simple t-test on proportions (should use logistic) (also pseudoreplicates within regions)
	t.test(goalsmetbymod1out$pmet[goalsmetbymod1out$period=='2081-2100'], goalsmetbymod2out$pmet[goalsmetbymod2out$period=='2081-2100'], paired=FALSE)

	# GLMM model (since proportion data) on 2006-2020
	require(lme4)
	require(car)
	mod <- glmer(cbind(nmet, nmet/pmet - nmet) ~ plan + (1|region/rcp/model), data=goalsmetbymod, family='binomial', subset=goalsmetbymod$period=='2006-2020')
	summary(mod)
	Anova(mod)

	# GLMM model (since proportion data) on 2041-2060
	require(lme4)
	require(car)
	goalsmetbymod <- rbind(goalsmetbymod1out, goalsmetbymod2out)
	mod <- glmer(cbind(nmet, nmet/pmet - nmet) ~ plan + (1|region/rcp/model), data=goalsmetbymod, family='binomial', subset=goalsmetbymod$period=='2041-2060')
	summary(mod)
	Anova(mod)

	# GLMM model (since proportion data) on 2081-2100
	goalsmetbymod <- rbind(goalsmetbymod1out, goalsmetbymod2out)
	mod <- glmer(cbind(nmet, nmet/pmet - nmet) ~ plan + (1|region/rcp/model), data=goalsmetbymod, family='binomial', subset=goalsmetbymod$period=='2081-2100')
	summary(mod)
	Anova(mod)

	# GLMM model (since proportion data) across all time periods
	goalsmetbymod <- rbind(goalsmetbymod1out, goalsmetbymod2out)
	mod <- glmer(cbind(nmet, nmet/pmet - nmet) ~ plan + (1|region/rcp/model/period), data=goalsmetbymod, family='binomial')
	summary(mod)
	Anova(mod)


# plot %goals met (solution #1)
	# quartz(width=4, height=4)
#	colmat <- t(col2rgb(brewer.pal(4, 'Paired')))
	colmat <- t(col2rgb(brewer.pal(4, 'Dark2')))
	cols <- rgb(red=colmat[,1], green=colmat[,2], blue=colmat[,3], alpha=c(255,255,255,255), maxColorValue=255)
	mods <- sort(unique(goalsmetbymod1$model))
	rcps <- sort(unique(goalsmetbymod1$rcp))
	outfile <- paste('cmsp_figures/MarZone_', myreg, '_goalsmetbymod_', runtype, projtype, '_', runname1, '.pdf', sep='')
		outfile
	pdf(width=4, height=4, file=outfile)

	inds <- goalsmetbymod1$model == mods[1] & goalsmetbymod1$rcp == rcps[1]
	plot(goalsmetbymod1$mid[inds], goalsmetbymod1$pmet[inds], xlab='Year', ylab='Fraction goals met', ylim=c(0.5, 1), type='l', pch=16, las=1, col=cols[1])
	for(i in 1:length(mods)){
		for(j in 1:length(rcps)){
			if(!(i==1 & j==1)){
				inds <- goalsmetbymod1$model == mods[i] & goalsmetbymod1$rcp == rcps[j]
				points(goalsmetbymod1$mid[inds], goalsmetbymod1$pmet[inds], type='l', pch=16, col=cols[1])	
			}
		}
	}
	ensmean <- aggregate(list(nmet=goalsmetbymod1$nmet, pmet=goalsmetbymod1$pmet), by=list(mid=goalsmetbymod1$mid), FUN=mean)
	lines(ensmean$mid, ensmean$pmet, col=cols[2], lwd=2)

	
	dev.off()
	
# plot %goals met (solution #1 and #2)
	colmat <- t(col2rgb(brewer.pal(4, 'Paired')))
#	colmat <- t(col2rgb(brewer.pal(4, 'Dark2')))
	cols <- rgb(red=colmat[,1], green=colmat[,2], blue=colmat[,3], alpha=c(255,255,255,255), maxColorValue=255)
	outfile <- paste('cmsp_figures/MarZone_allregs_goalsmetbymod_', runtype, projtype, '_', runname1out, '&', runname2out, '.pdf', sep='')
		outfile
	ylims <- c(0.3,1)

	# quartz(width=6, height=6)
	pdf(width=6, height=6, file=outfile)
	par(mfrow=c(3,3), mai=c(0.3, 0.35, 0.2, 0.05), omi=c(0.2,0.2,0,0), cex.main=0.8)

	for(i in 1:length(myregs)){
		inds <- goalsmetbymod1out$model == mods[1] & goalsmetbymod1out$rcp == rcps[1] & goalsmetbymod1out$region==myregs[i]
		plot(goalsmetbymod1out$mid[inds], goalsmetbymod1out$pmet[inds], xlab='', ylab='', ylim=ylims, type='l', pch=16, las=1, col=cols[1], main=regnames[i])
		for(k in 1:length(mods)){
			for(j in 1:length(rcps)){
				if(!(k==1 & j==1)){
					inds <- goalsmetbymod1out$model == mods[k] & goalsmetbymod1out$rcp == rcps[j] & goalsmetbymod1out$region==myregs[i]
					points(goalsmetbymod1out$mid[inds], goalsmetbymod1out$pmet[inds], type='l', pch=16, col=cols[1])	
				}
			}
		}
		inds <- goalsmetbymod1out$region==myregs[i]
		ensmean <- aggregate(list(nmet=goalsmetbymod1out$nmet[inds], pmet=goalsmetbymod1out$pmet[inds]), by=list(mid=goalsmetbymod1out$mid[inds]), FUN=mean)
		lines(ensmean$mid, ensmean$pmet, col=cols[2], lwd=2)

		for(k in 1:length(mods)){
			for(j in 1:length(rcps)){
				inds <- goalsmetbymod2out$model == mods[k] & goalsmetbymod2out$rcp == rcps[j] & goalsmetbymod2out$region==myregs[i]
				points(goalsmetbymod2out$mid[inds], goalsmetbymod2out$pmet[inds], type='l', pch=16, col=cols[3])
			}	
		}
		inds <- goalsmetbymod2out$region==myregs[i]
		ensmean2 <- aggregate(list(nmet=goalsmetbymod2out$nmet[inds], pmet=goalsmetbymod2out$pmet[inds]), by=list(mid=goalsmetbymod2out$mid[inds]), FUN=mean)
		lines(ensmean2$mid, ensmean2$pmet, col=cols[4], lwd=2)
	}
	mtext(side=1,text='Year',line=0.5, outer=TRUE)
	mtext(side=2,text='Fraction goals met',line=0.3, outer=TRUE)
	
	dev.off()
	
	
## probability of < 80% goals met by region, plan, and time period
	# calcs
	u80func <- function(x) return(sum(x<0.8)/length(x))	
	u80 <- with(goalsmetbymod, aggregate(list(u80=pmet), by=list(region=region, period=period, plan=plan), FUN=u80func))


	# examine
	u80[u80$period=='2041-2060',] # middle of century, by region
	u80[u80$period=='2081-2100',] # end of century, by region
	
	with(u80[u80$period=='2041-2060',], aggregate(list(meanu80=u80), by=list(plan=plan), FUN=mean)) # means by plan (across regions), middle of century
	with(u80[u80$period=='2081-2100',], aggregate(list(meanu80=u80), by=list(plan=plan), FUN=mean)) # means by plan (across regions), end of century

	a<-aggregate(list(max_u80=u80$u80), by=list(region=u80$region, plan=u80$plan), FUN=max) # max probability of being under 80% of goals met (look across time periods)
		mean(a$max_u80[a$plan=='2per'])
		mean(a$max_u80[a$plan=='histonly'])
	
	# plot
	require(lattice)
	xyplot(u80 ~ period | region, data=u80, groups=plan, type='l')