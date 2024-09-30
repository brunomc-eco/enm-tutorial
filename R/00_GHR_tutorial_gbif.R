# Exploring species occurrence data from GBIF
# Bruno Carvalho
# GHR Tutorial 12 May 2023

# Load packages
library(CoordinateCleaner)
library(leaflet)

# Load raw data downloaded from GBIF
filename = "./data/gbif/aedes_albopictus_Spain.csv"
occs <- read.csv(filename, sep = "\t") # GBIF files are tab-delimited by default

# First check of total number of records
n_occs1 <- nrow(occs)
print(n_occs1)

# Have a look at the variable names
names(occs) # GBIF data follows the DarwinCore standard <https://dwc.tdwg.org>

# Which species names do we have there?
unique(occs$scientificName)

# Which unique taxon identifiers do we have there?
unique(occs$taxonKey)

# Check GBIF known issues - check <https://data-blog.gbif.org/post/issues-and-flags/>
gbif_issues <- table(occs$issue)
View(gbif_issues) # if you're using RStudio

# How many records without coordinates?
na_coords <- nrow(occs[is.na(occs$decimalLatitude) & is.na(occs$decimalLongitude), ])
print(na_coords)

# Remove records without coordinates
occs <- occs[!is.na(occs$decimalLatitude) & !is.na(occs$decimalLongitude), ]

# Second check of total number of records
n_occs2 <- nrow(occs)
print(n_occs2)

# Visual inspection of the raw data 
# (WARNING: if number of records is too high, leaflet may crash!)
leaflet(data = occs) %>% 
  addTiles() %>%
  addCircleMarkers(
    lng = ~decimalLongitude,
    lat = ~decimalLatitude,
    radius = 5,
    color = "black",
    stroke = FALSE,
    fillOpacity = 0.5
  )

# If you have too many records you can do a quick inspection of their shape here:
plot(decimalLatitude ~ decimalLongitude, data = occs)

# Basic spatial cleaning of records
occs_clean <- clean_coordinates(occs,
                                species = "scientificName",
                                lon = "decimalLongitude",
                                lat = "decimalLatitude",
                                tests = c(
                                  "zeros", # zeros in lat and/or lon
                                  "equal", # equal lat and lon
                                  "centroids", # country centroids
                                  "gbif", # GBIF headquarters in Copenhagen
                                  "institutions", # known biodiversity institutions
                                  "duplicates" # identical lat/lon between records
                                   ),
                                value = "clean") #try using "spatialvalid" to keep all records and test results

# Third check of total number of records
n_occs3 <- nrow(occs_clean)
print(n_occs3)

# Final look at total number of records
df <- data.frame(type = c("raw dataset", 
                          "after removing NAs in coords", 
                          "after cleaning"), 
                 n_occs = c(n_occs1, n_occs2, n_occs3))

barplot(height=df$n_occs, 
        names=df$type, 
        ylim=c(0,(max(df$n_occs)+0.1*max(df$n_occs))))

# Visual inspection of the cleaned data
leaflet(data = occs_clean) %>% 
  addTiles() %>%
  addCircleMarkers(
    lng = ~decimalLongitude,
    lat = ~decimalLatitude,
    radius = 5,
    color = "black",
    stroke = FALSE,
    fillOpacity = 0.5
  )

# Save output file with cleaned records
out_filename = "./output/00_species_cleaned.csv"

write.csv(occs_clean, file = out_filename)
