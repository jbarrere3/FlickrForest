#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#
#### SCRIPT INTRODUCTION ####
#
#' @name functions_plot.R  
#' @description R script containing all functions relative to plots
#' @author Julien Barrere
#
#
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#' Function to plot the photos taken in each PNR
#' @param flickr_data dataset with pictures location
#' @param pnr_files shapefiles of the pnr
#' @param file.out Name of the file to save, including path
plot_location_pnr = function(flickr_data, pnr_files, file.out){
  
  # Create output directory if needed
  create_dir_if_needed(file.out)
  
  # Convert flickr data into sf format
  flickr_data_sf = flickr_data %>%
    st_as_sf(coords = c("Longitude", "Latitude"), crs = 4326, agr = "constant")
  
  # List all pnr
  pnr.vec = unique(flickr_data_sf$pnr)
  
  # Initialise output list of plots
  plotlist.out = vector(mode = "list", length = length(pnr.vec))
  
  # Loop on all pnr
  for(i in 1:length(pnr.vec)){
    
    # pnr i
    pnr.i = pnr.vec[i]
    pnr_file.i = pnr_files[grep(pnr.i, pnr_files)]
    pnr.shp.i = read_sf(pnr_file.i)
    
    # Make plot for pnr i
    plotlist.out[[i]] = pnr.shp.i %>%
      ggplot(aes(geometry = geometry)) +
      geom_sf(fill = "lightgreen", show.legend = F, size = 0.2) + 
      geom_sf(data = subset(flickr_data_sf, pnr == pnr.i), 
              shape = 21, color = "black", fill = "red", alpha = 0.3) +
      theme(panel.background = element_rect(color = 'black', fill = 'white'), 
            panel.grid = element_blank(), 
            plot.title = element_text(hjust = 0.5, size = 18), 
            axis.text = element_text(size = 13)) + 
      ggtitle(paste0("PNR of ", pnr.i, "\n(n = ", 
                     length(which(flickr_data_sf$pnr == pnr.i)), ")"))
  }
  
  # Compile all plots
  plot.out = plot_grid(plotlist = plotlist.out, nrow = 1, align = "hv", scale = 0.95)
  
  # - Save the plot
  ggsave(file.out, plot.out, width = 30, height = 12, 
         units = "cm", dpi = 600, bg = "white")
  
  # return the name of the plot exported
  return(file.out)
  
  
}
