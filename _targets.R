#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#
#### SCRIPT INTRODUCTION ####
#
#' @name _targets.R  
#' @description R script to launch the target pipeline
#' @author Julien BARRERE
#
#
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Options and packages ----------------
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# Load targets
library(targets)
# Load functions
lapply(grep("R$", list.files("R"), value = TRUE), function(x) source(file.path("R", x)))
# install if needed and load packages
packages.in <- c("dplyr", "ggplot2", "tidyr", "data.table", "sf", "stringr", 
                 "rnaturalearth", "rnaturalearthdata", "cowplot", "terra")
for(i in 1:length(packages.in)) if(!(packages.in[i] %in% rownames(installed.packages()))) install.packages(packages.in[i])
# Targets options
options(tidyverse.quiet = TRUE)
tar_option_set(packages = packages.in)
set.seed(2)


#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Targets workflow --------------------
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

list(
  
  # Shapefiles of Natural regional parks (PNR)
  # - Original file with all pnr
  tar_target(pnr_file, "data/PNR/pnr_polygonPolygon.shp", format = "file"), 
  # - code and name of the PNR to select
  tar_target(code_table, data.frame(osm_id = c(-9083986), 
                                    PNR = c("SainteBaume"))),
  # tar_target(code_table, data.frame(osm_id = c(-9083986, -5488646, -3094803), 
  #                                   PNR = c("SainteBaume", "Baronnies", "Alpilles"))),
  # - Make separate shp for each pnr selected
  tar_target(pnr_files, divide_pnr_shp(pnr_file, code_table, "export/shp")), 
  
  # Extraction of Flickr data
  # - Table of files to extract
  tar_target(extraction_table, build_extraction_table(
    pnr_files, "export", years = c(2015:2024))), 
  # - Launch extraction via python
  tar_target(flickr_files, extract_flickr(extraction_table, with.pic = TRUE), 
             format = "file"), 
  # - Compile data extracted into one single dataframe
  tar_target(flickr_data, compile_flickr(flickr_files)),

  # Plot the location of pictures in each PNR
  tar_target(fig_flickr_location, plot_location_pnr(
    flickr_data, pnr_files, "export/fig/fig_location_flickr.jpg"), format = "file")
  
)
  
  