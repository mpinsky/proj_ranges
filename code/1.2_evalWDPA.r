# evaluate protected areas against shifts in species distribution
# calculate species gains, losses, turnover, etc.


############
## Flags
############

# choose the rcp(s)
RCPS <- c(26, 85)

# select initial and final timeperiod for these grids
PERIODS <- c('2007-2020', '2081-2100')

# number of climate models in the projections
NMODS <- 18

# path to the pres-abs projection results from Morley et al. 2018. At 0.05 grid size.
PRESABSPATH <- '/local/shared/pinsky_lab/projections_PlosOne2018/CEmodels_proj_PresAbs_May2018' 


####################
## helper functions
####################
require(data.table)
# set default rounding (2 bytes) so that data.table will merge numeric values appropriately
# see https://rdrr.io/rforge/data.table/man/setNumericRounding.html
setNumericRounding(2)

#require(lme4) # for mixed-effects models
#require(car) # for testing ME models
#require(Hmisc)



###########################
## Load and set up WDPA data
###########################

wdpagrid <- fread('gunzip -c output/wdpa_cov_by_grid0.05.csv.gz', drop = 1) # shows which MPAs are in which grid cells. each line is a unique grid cell-MPA combination.
	
	# convert lon to -360 to 0 (instead of -180 to 180) to match the pres/abs projections and to plot more nicely
	wdpagrid[lon>0, lon := lon-360]

	# set up MPA networks
	wdpagrid[SUB_LOC == 'US-CA' & MANG_AUTH == 'State Fish and Wildlife',network := 'mlpa']
	wdpagrid[grepl('US-DE|US-FL|US-GA|US-MA|US-MD|US-ME|US-NC|US-NJ|US-NY|US-RI|US-SC|US-VA', SUB_LOC) & !grepl('US-N/A', SUB_LOC) & (lon > -100), network := 'eastcoast'] # by exluding US-N/A, this won't include federal water closures
	wdpagrid[(SUB_LOC %in% c('US-AK')), network := 'ak'] # by choosing by state, this won't include federal water closures
	
	# calculate mpa extent
	wdpagrid[, ':='(lat_min = min(lat), lat_max = max(lat), lon_min = min(lon), lon_max = max(lon)), by = WDPA_PID]

#	wdpagrid[network=='mlpa',plot(lon,lat)]
#	wdpagrid[network=='eastcoast',plot(lon,lat)]
#	wdpagrid[network=='ak',plot(lon,lat)]
#	require(maps); map(database='world2',add=TRUE)

	
##############################################################
# Load in pres/abs results for each RCP and each species
# and calculate summary statistics by MPA
##############################################################
# the list of MPAs. Turnover data will be added as columns to this
wdpa <- wdpagrid[!duplicated(WDPA_PID), ] 
wdpa[,c('gridpolyID', 'lat', 'lon', 'area_wdpa', 'area_grid', 'prop_grid', 'prop_wdpa') := NULL] # remove gridcell-specific columns

# step through each species' projections
projcols <- c('lat', 'lon', paste0('mean', 1:NMODS)) # names of columns in pred.agg to use (the projections)
for (i in 1:length(RCPS)) {
    print(paste0(Sys.time(), ' On RCP ', RCPS[i], '. Species: '))
    files <- list.files(path = PRESABSPATH, pattern = paste('*rcp', RCPS[i], '*', sep = ''), full.names = TRUE)

    # load presmap for each model run and process the results
    # then calculate change in p(occur)
    for (j in 1:length(files)) {
        cat(paste0(' ', j))
        load(files[j]) # loads pred.agg data.frame
        pred.agg <- as.data.table(pred.agg)
        
        # round lat lon to nearest 0.05 so that merging is successful with WDPA
        pred.agg[, lat := floor(latitude*20)/20 + 0.025] # assumes 0.05 grid size
        pred.agg[, lon := floor(longitude*20)/20 + 0.025] # assumes 0.05 grid size
        setkey(pred.agg, lat, lon)
        
        # scale up from tow to grid area: not done
        # D <- 365*20/(20/60/24) # number of tows in 20 years (currently hard-coded for NEUS 20 minutes)
        # pred.agg[, Agrid := 2*pi*6371^2*abs(sin((latitude - 0.025)*pi/180) - sin(pi/180*(latitude + 0.025)))*0.05/360] # area of each 0.05 grid in km2. See http://mathforum.org/library/drmath/view/63767.html
        # pred.agg[, A := Agrid/0.0384] # number of tows in one 0.05 grid cell (currently hard-coded for NEUS)
        # for (m in 1:NMODS) { # for each climate model
        #     pred.agg[, (paste0('scaled', m)) := 1 - (1 - get(paste0('mean', m)))^A] # 1-(1-p)^D^A
        # }
 
        # reorganize so that time 2 and time 1 are separate columns, rows are locations
        presbyloc <- merge(pred.agg[year_range == PERIODS[1], ..projcols], pred.agg[year_range == PERIODS[2], ..projcols], by = c('lat', 'lon'), suffixes = c('.t1', '.t2'))

        # merge pres/abs data with WDPA grid data and calculate summary stats about species change through time
        # summary stat column names are of form [sumstatname].[RCP].[modnumber]
        wdpagridspp <- merge(wdpagrid, presbyloc, all.x = TRUE, by = c('lat', 'lon'))
        for (m in 1:NMODS) { # for each climate model
            wdpagridspp[is.na(wdpagridspp[[paste0('mean', m, '.t1')]]), (paste0('mean', m, '.t1')) := 0] # set NAs to 0 (species not present)
            wdpagridspp[is.na(wdpagridspp[[paste0('mean', m, '.t2')]]), (paste0('mean', m, '.t2')) := 0]

            # aggregate p(occur) across grid cells into full MPAs
            sppbyMPA <- wdpagridspp[, .(pinit = 1 - prod(1 - get(paste0('mean', m, '.t1'))*prop_wdpa), # p(occur whole MPA) at initial timepoint as 1 - prod(1-p(occur per grid))
                                 pfinal = 1 - prod(1 - get(paste0('mean', m, '.t2'))*prop_wdpa)
                                 ), by = WDPA_PID]
            #print(dim(sppbyMPA))
            
            # merge wpda with sppbyMPA (latter has results from the current species)
            wdpa <- merge(wdpa, sppbyMPA, by = 'WDPA_PID')
            
            # calculate summary stats by network and add this species onto results from previous species
            if (!(paste0('ninit.', RCPS[i], '.', m) %in% colnames(wdpa))) { # if output column in wdpa doesn't yet exist, create it
                wdpa[, (paste0('ninit.', RCPS[i], '.', m)) := pinit]
                wdpa[, (paste0('nfinal.', RCPS[i], '.', m)) := pfinal]
                wdpa[, (paste0('nshared.', RCPS[i], '.', m)) := pinit*pfinal]
                wdpa[pinit > pfinal, (paste0('nlost.', RCPS[i], '.', m)) := pinit - pfinal]
                wdpa[pinit <= pfinal, (paste0('nlost.', RCPS[i], '.', m)) := 0]
                wdpa[pinit < pfinal, (paste0('ngained.', RCPS[i], '.', m)) := pfinal - pinit]
                wdpa[pinit >= pfinal, (paste0('ngained.', RCPS[i], '.', m)) := 0]
            } else {# if columns already exist, add the new species' values onto the existing values
                wdpa[, (paste0('ninit.', RCPS[i], '.', m)) := get(paste0('ninit.', RCPS[i], '.', m)) + pinit]
                wdpa[, (paste0('nfinal.', RCPS[i], '.', m)) := get(paste0('nfinal.', RCPS[i], '.', m)) + pfinal]
                wdpa[, (paste0('nshared.', RCPS[i], '.', m)) := get(paste0('nshared.', RCPS[i], '.', m)) + pinit*pfinal]
                wdpa[pinit > pfinal, (paste0('nlost.', RCPS[i], '.', m)) := get(paste0('nlost.', RCPS[i], '.', m)) + pinit - pfinal]
                wdpa[pinit < pfinal, (paste0('ngained.', RCPS[i], '.', m)) := get(paste0('ngained.', RCPS[i], '.', m)) + pfinal - pinit]
            }
            wdpa[, c('pinit', 'pfinal') := NULL] # delete the species-specific columns now that we have the summaries we need
        }
       # wdpa[,print(max(get(paste0('ninit.', RCPS[i], '.1'))))] # a test that cumulative sums are being calculated. Should increase through the loop
    }
}
print(Sys.time())

dim(wdpa) # 923 x 127

# how many rows are zero?
wdpa[, .(sum(ninit.26.1 == 0), sum(ninit.85.1 == 0))]
wdpa[, .(sum(ninit.26.1 > 0), sum(ninit.85.1 > 0))]
    # wdpa[ninit.26.1 > 0, plot(lon_max, lat_max, cex = 0.1, xlim=c(-190, 0))]
    # wdpa[ninit.26.1 == 0, points(lon_max, lat_max, cex = 0.5, col = 'red')]

# write out species data 
write.csv(wdpa, file = gzfile('temp/wdpaturnbyMPAbymod.csv.gz'))

# wdpa <- fread('gunzip -c temp/wdpaturnbyMPAbymod.csv.gz', drop = 1) # don't read the row numbers



##############################################
# Calculate turnover within select MPA networks
# For each model in the ensemble
##############################################
wdpanet <- wdpagrid[!is.na(network), .(lat = mean(lat), lon = mean(lon), area = sum(area_fullwdpa)), by = network ] # the list of MPA networks. Turnover data will be added as columns to this


projcols <- c('lat', 'lon', paste0('mean', 1:NMODS)) # names of columns in pred.agg to use (the projections)
for (i in 1:length(RCPS)) {
    print(paste0(Sys.time(), ' On RCP ', RCPS[i], '. Species: '))
    files <- list.files(path = PRESABSPATH, pattern = paste('*rcp', RCPS[i], '*', sep = ''), full.names = TRUE)

    # load presmap for each model run and process the results
    # then calculate change in p(occur)
    for (j in 1:length(files)) {
        cat(paste0(' ', j))
        load(files[j]) # loads pred.agg data.frame
        pred.agg <- as.data.table(pred.agg)
        
        # round lat lon to nearest 0.05 so that merging is successful with WDPA
        pred.agg[, lat := floor(latitude*20)/20 + 0.025] # assumes 0.05 grid size
        pred.agg[, lon := floor(longitude*20)/20 + 0.025] # assumes 0.05 grid size
        setkey(pred.agg, lat, lon)
        
        # scale up from tow to grid area: not done
        # D <- 365*20/(20/60/24) # number of tows in 20 years (currently hard-coded for NEUS 20 minutes)
        # pred.agg[, Agrid := 2*pi*6371^2*abs(sin((latitude - 0.025)*pi/180) - sin(pi/180*(latitude + 0.025)))*0.05/360] # area of each 0.05 grid in km2. See http://mathforum.org/library/drmath/view/63767.html
        # pred.agg[, A := Agrid/0.0384] # number of tows in one 0.05 grid cell (currently hard-coded for NEUS)
        # for (m in 1:NMODS) { # for each climate model
        #     pred.agg[, (paste0('scaled', m)) := 1 - (1 - get(paste0('mean', m)))^A] # 1-(1-p)^D^A
        # }
 
        # reorganize so that time 2 and time 1 are separate columns, rows are locations
        presbyloc <- merge(pred.agg[year_range == PERIODS[1], ..projcols], pred.agg[year_range == PERIODS[2], ..projcols], by = c('lat', 'lon'), suffixes = c('.t1', '.t2'))

        # merge pres/abs data with WDPA grid data and calculate summary stats about species change through time
        # summary stat column names are of form [sumstatname].[RCP].[modnumber]
        wdpagridspp <- merge(wdpagrid, presbyloc, all.x = TRUE, by = c('lat', 'lon'))
        for (m in 1:NMODS) { # for each climate model
            wdpagridspp[is.na(wdpagridspp[[paste0('mean', m, '.t1')]]), (paste0('mean', m, '.t1')) := 0] # set NAs to 0 (species not present)
            wdpagridspp[is.na(wdpagridspp[[paste0('mean', m, '.t2')]]), (paste0('mean', m, '.t2')) := 0]

            # aggregate p(occur) across grid cells into full MPA networks
            sppbynet <- wdpagridspp[!is.na(network), .(pinit = 1 - prod(1 - get(paste0('mean', m, '.t1'))*prop_wdpa), # p(occur whole MPA) at initial timepoint as 1 - prod(1-p(occur per grid))
                                 pfinal = 1 - prod(1 - get(paste0('mean', m, '.t2'))*prop_wdpa)
                                 ), by = network]
            #print(dim(sppbynet))
            
            # merge wpda with sppbynet (latter has results from the current species)
            wdpanet <- merge(wdpanet, sppbynet, by = 'network')
            
            # calculate summary stats and add this species onto results from previous species
            if (!(paste0('ninit.', RCPS[i], '.', m) %in% colnames(wdpanet))) { # if output column in wdpanet doesn't yet exist, create it
                wdpanet[, (paste0('ninit.', RCPS[i], '.', m)) := pinit]
                wdpanet[, (paste0('nfinal.', RCPS[i], '.', m)) := pfinal]
                wdpanet[, (paste0('nshared.', RCPS[i], '.', m)) := pinit*pfinal]
                wdpanet[pinit > pfinal, (paste0('nlost.', RCPS[i], '.', m)) := pinit - pfinal]
                wdpanet[pinit <= pfinal, (paste0('nlost.', RCPS[i], '.', m)) := 0]
                wdpanet[pinit < pfinal, (paste0('ngained.', RCPS[i], '.', m)) := pfinal - pinit]
                wdpanet[pinit >= pfinal, (paste0('ngained.', RCPS[i], '.', m)) := 0]
            } else {# if columns already exist, add the new species' values onto the existing values
                wdpanet[, (paste0('ninit.', RCPS[i], '.', m)) := get(paste0('ninit.', RCPS[i], '.', m)) + pinit]
                wdpanet[, (paste0('nfinal.', RCPS[i], '.', m)) := get(paste0('nfinal.', RCPS[i], '.', m)) + pfinal]
                wdpanet[, (paste0('nshared.', RCPS[i], '.', m)) := get(paste0('nshared.', RCPS[i], '.', m)) + pinit*pfinal]
                wdpanet[pinit > pfinal, (paste0('nlost.', RCPS[i], '.', m)) := get(paste0('nlost.', RCPS[i], '.', m)) + pinit - pfinal]
                wdpanet[pinit < pfinal, (paste0('ngained.', RCPS[i], '.', m)) := get(paste0('ngained.', RCPS[i], '.', m)) + pfinal - pinit]
            }
            wdpanet[, c('pinit', 'pfinal') := NULL] # delete the species-specific columns now that we have the summaries we need
        }
        # wdpanet[,print(max(get(paste0('ninit.', RCPS[i], '.1'))))] # a test that cumulative sums are being calculated. Should increase through the loop
    }
}
print(Sys.time())

dim(wdpanet) # 923 x 127

# how many rows are zero?
wdpanet[, .(sum(ninit.26.1 == 0), sum(ninit.85.1 == 0))]
wdpanet[, .(sum(ninit.26.1 > 0), sum(ninit.85.1 > 0))]
    # wdpanet[ninit.26.1 > 0, plot(lon_max, lat_max, cex = 0.1, xlim=c(-190, 0))]
    # wdpanet[ninit.26.1 == 0, points(lon_max, lat_max, cex = 0.5, col = 'red')]

# write out species data 
write.csv(wdpanet, file = gzfile('temp/wdpaturnbynetbymod.csv.gz'), row.names = FALSE)

# wdpanet <- fread('gunzip -c temp/wdpaturnbynetbymod.csv.gz') # don't read the row numbers

