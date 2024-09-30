# Pre-processing input data for ENM
# Bruno Carvalho
# GHR Tutorial 23 Jun 2023

# Load packages
library(sf)
library(raster)
library(dismo)
library(readr)
library(dplyr)

# load species data
occs_clean <- read_csv("./output/00_species_cleaned.csv")

# load country borders shapefile
countries <- st_read("./data/shp/World_Countries_Generalized/World_Countries_Generalized.shp")

# load climatic variables
wc_files <- list.files(path = "./data/worldclim",	pattern = ".tif", full.names = TRUE)
wc <- stack(wc_files)


#### 1. Prepare single country mask ####

# get country from species data
my_country <- countries %>% 
  filter(ISO == unique(occs_clean$countryCode))

# check if map looks correct
plot(st_geometry(my_country))

# alternative option: using country name in English
#my_country <- countries %>% 
#  filter(COUNTRY == "Spain")


#### 2. Crop climate data to country of choice ####

# crop climate data to country of choice
climate <- crop(wc, extent(my_country))

# mask out values outside country borders
climate <- mask(climate, my_country)

# renaming climatic layers for simplicity
names(climate) <- c("bio1", "bio12", "bio15", "bio4") 

# check if maps look correct
plot(climate)


#### 3. Sample pseudoabsences ####

# randomly sampling 10 times the number of presences in study area
abs <- randomPoints(climate, 
                    n = 10 * nrow(occs_clean),
                    p = data.frame(occs_clean[ , c("decimalLongitude", "decimalLatitude")]),
                    excludep = TRUE)

# You might see an error message saying that 
# the total number of points could not be sampled
# because the extent is not large enough.
# The function automatically adjusts to the maximum
# possible number of points.

# Check again if all looks correct
plot(climate[[1]], main = names(climate[[1]]))
points(occs_clean$decimalLongitude, 
       occs_clean$decimalLatitude,
       pch = 20, cex = 0.5, col = "black") # presences in black
points(abs[ ,1], abs[ ,2], pch = 20, 
       cex = 0.5, col = "red") # pseudoabsences in red


#### 4. Extract climate values in points ####

# creating presence/absence dataset
df <- tibble(species = unique(occs_clean$species),
             pa = c(rep(1, nrow(occs_clean)), rep(0, nrow(abs))),
             lon = c(occs_clean$decimalLongitude, abs[,1]),
             lat = c(occs_clean$decimalLatitude, abs[,2]))

# extracting climate values
clim_vals <- extract(climate, dplyr::select(df, lon, lat))

# add extracted climate values to dataset
df <- bind_cols(df, clim_vals)

# have a look at the initial values
head(df)

# save harmonized dataset
write_csv(df, "./output/01_harmonized_data.csv")

# save harmonized climate predictors 
writeRaster(climate, "./output/01_predictors.grd", format = "raster", overwrite=TRUE)
