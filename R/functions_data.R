#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#
#' @name functions_data.R  
#' @description R script containing all functions relative to data
#               importation and formatting
#' @author Julien Barrere
#
#
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#### -- Generic functions ------------------
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


#' Get file from its url and write it on disk, at a specified location. 
#' @param dir.name.in Directory where the file should be written (ex: "data/BWI")
#' @param url.in URL where to download the file.
get_and_write <- function(dir.name.in, url.in){
  
  # Write directories if they do not exist
  path.in <- strsplit(dir.name.in, "/")[[1]]
  for(i in 1:length(path.in)){
    if(i == 1) path.in_i <- path.in[i]
    else path.in_i <- paste(path.in_i, path.in[i], sep = "/")
    if(!dir.exists(path.in_i)) dir.create(path.in_i)
  }
  
  # Write file on the disk
  url.in_split <- strsplit(url.in, "/")[[1]]
  file.in <- paste(dir.name.in, url.in_split[length(url.in_split)], sep = "/")
  if(!file.exists(file.in)){
    try(GET(url.in, authenticate('guest', ""), write_disk(file.in, overwrite = TRUE)))
    # Specific case of zip file: unzip and delete zip file
    if("zip" %in% strsplit(file.in, split = "\\.")[[1]]){
      unzip(file.in, exdir = dir.name.in, overwrite = T)
      print(paste0("---Getting and unzipping ", file.in))
      unlink(file.in)
    }else{print(paste0("---Getting ", file.in))}
  } 
}




#' Function to get the path of a file, and create directories if they don't exist
#' @param file.in character: path of the file, filename included (ex: "plot/plot.png")
create_dir_if_needed <- function(file.in){
  
  path.in <- strsplit(file.in, "/")[[1]]
  if(length(path.in) > 1){
    for(i in 1:(length(path.in)-1)){
      if(i == 1) path.in_i <- path.in[i]
      else path.in_i <- paste(path.in_i, path.in[i], sep = "/")
      if(!dir.exists(path.in_i)) dir.create(path.in_i)
    }
  }
}

#' Write a table on disk
#' @param table.in dataframe to write on the disk
#' @param file.in Name (and path) of the file on the disk
write_on_disk <- function(table.in, file.in){
  create_dir_if_needed(file.in)
  write.table(table.in, file = file.in, row.names = F, sep = ",")
  return(file.in)
}




#' Function to divide the pnr shapefile into individual shapefiles for each selected PNR
#' @param pnr_file shapefile containing all pnr in France
#' @param code_table table linking each PNR to a code in pnf_file and a short name
#' @param dir.out directory where to export shapefiles created
divide_pnr_shp = function(pnr_file, code_table, dir.out){
  
  # read shapefile
  pnr_sf = read_sf(pnr_file)
  
  # Name of the files to export
  files.out = paste0(dir.out, "/pnr_", code_table$PNR, ".shp")
  
  # Create output directory if needed
  create_dir_if_needed(files.out[1])
  
  # Loop on all pnr to make shapefiles
  for(i in 1:dim(code_table)[1]){
    
    # Create shapefile
    shp.i = pnr_sf %>%
      filter(osm_id == code_table$osm_id[i]) %>%
      select(`ID_pnr` = `osm_id`)  %>%
      mutate(PNR = code_table$PNR[i]) %>%
      st_transform(crs = 4326)
    
    # Write shapefile
    st_write(shp.i, files.out[i])
  }
  
  # Return the files produced
  return(files.out)
  
}


#' Function to build an extraction table for Flickr data
#' @param pnr_files locatin of PNR shapefiles
#' @param dir.out directory where txt files will be exported
#' @param years vector of years for which to extract data
build_extraction_table = function(pnr_files, dir.out, years){
  
  expand_grid(pnr_file = pnr_files, 
              trimester = c("01-01_03-31", "04-01_06-30", "07-01_09-30", "10-01_12-31"), 
              year = years) %>%
    mutate(pnr = gsub(".+\\_", "", gsub("\\.shp", "", pnr_file))) %>%
    separate(col = trimester, into = c("start", "end"), sep = "_") %>%
    mutate(start_date = paste0(year, "-", start), 
           end_date = paste0(year, "-", end), 
           file.out = paste0(dir.out, "/txt/", pnr, "_", start_date, "_", 
                             end_date, ".txt"), 
           dir.pic.out = paste0(dir.out, "/pic")) %>%
    select(pnr, pnr_file, start_date, end_date, file.out, dir.pic.out)
  
}

#' Extract Flickr location data for each pnr
#' @param extraction_table Table listing all files to extract, date and pnr
#' @param with.pic Boolean to indicate weather to download pictures or not
extract_flickr = function(extraction_table, with.pic = FALSE){
  
  # Create output directory if needed
  create_dir_if_needed(extraction_table$file.out[1])
  create_dir_if_needed(paste0(extraction_table$dir.pic.out[1], "/test"))
  
  # Loop on all files to extract
  for(i in 1:dim(extraction_table)[1]){
    
    # Printer
    print(paste0("Extraction ", i, "/", dim(extraction_table)[1], 
                 " : Pictures from ", extraction_table$start_date[i], 
                 " to ", extraction_table$end_date[i], " in PNR ", 
                 extraction_table$pnr[i]))
    
    # Command for the extraction
    # If no download of pictures
    if(with.pic == FALSE) py.i = paste0(
      "python3 Python/extract_flickr.py --api_key 35706c04875726d356379f1862b72008", 
      " --shapefile ", extraction_table$pnr_file[i], " --start_date ", 
      extraction_table$start_date[i], " --end_date ", extraction_table$end_date[i], 
      " --output ", extraction_table$file.out[i]
    )
    # If download pictures, use the other script
    if(with.pic == TRUE) py.i = paste0(
      "python3 Python/extract_flickr_withpic.py --api_key 35706c04875726d356379f1862b72008", 
      " --shapefile ", extraction_table$pnr_file[i], " --start_date ", 
      extraction_table$start_date[i], " --end_date ", extraction_table$end_date[i], 
      " --output ", extraction_table$file.out[i], " --download_dir ", 
      extraction_table$dir.pic.out[i]
    )
    
    # Launch extraction via python
    system(py.i, wait = TRUE)
    
  }
  
  # Return all the files extracted
  return(extraction_table$file.out)
  
}

#' Function to read and compile photos extracted from Flickr
#' @param flickr_files list of files containing flickr pictures information
compile_flickr = function(flickr_files){
  
  # Loop on all files 
  for(i in 1:length(flickr_files)){
    
    # Check that the file exists
    if(file.exists(flickr_files[i])){
      # Read file i
      data.i = fread(flickr_files[i], fill = TRUE) %>%
        select(-URL) %>%
        mutate(pnr = gsub(".+\\/", "", gsub("\\_.+", "", flickr_files[i])), 
               ID = as.numeric(ID))
      
      # Add to the output dataset
      if(i == 1) out = data.i
      else out = rbind(out, data.i)
    }
  }
  
  # Return output
  return(out)
  
}