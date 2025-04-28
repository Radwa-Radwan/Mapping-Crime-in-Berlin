if (!require("pacman")) install.packages("pacman")
pacman::p_load(dplyr,
               tidyr,
               stringr,
               ggplot2,
               sf,
               readxl,
               tidygeocoder,
               purrr) 


source("functions.R")


folder_path <- "../final_data" # in case data is not already merged
file_list <- list.files(path = folder_path, pattern = "\\.xlsx$", full.names = TRUE)


# read and combine all LLM ouput subset files into one df
crime_dat_raw <- do.call(rbind, lapply(file_list, read_excel)) %>%
  mutate(report_id = row_number()) %>% select(report_id, everything()) # saved in data folder


# extract json tags from LLM raw results column
crime_dat <- crime_dat_raw %>% mutate(json_tags = sapply(crime_dat_raw$results, extract_json_tags)) %>% 
  separate_rows(json_tags, sep = ",,,,,")


# extract crime category, date, time and locations from json tags
crime_dat <- crime_dat %>% 
  mutate(crime_category =  str_extract(json_tags, '(?<=\\"crime_category\\": \\\")[^\\"]+(?=\\")')) %>%
  mutate(crime_date =  str_extract(json_tags, '(?<=\\"(date|crime_date)\\": \\")[^\\"]+')) %>%
  mutate(crime_time = str_extract(json_tags, '"time":\\s*"([0-9]{2}:[0-9]{2})"')) %>%
  mutate(crime_time = str_match(crime_time, '"time": "\\s*([0-9]{2}:[0-9]{2})"')[,2]) %>% 
  mutate(crime_location =  str_extract(json_tags, '(?<=\\"location\\": \\\")[^\\"]+(?=\\")')) 
  


# remove uncatogorized crime
crime_dat <- crime_dat %>% filter(!str_detect(crime_category, "none") | NA) # 3800 - 408 = 3392


# select target categories
target_cat <- c("Raub", "Körperverletzung", "Diebstahl", "Drogenkriminalität", "Beschädigung", "Übergriff", "Brandstiftung")
crime_dat <- crime_dat %>% filter(crime_category %in%  target_cat) # 3392 - 1012 = 2388

# filter crime incidents within year of 2024
crime_dat <- crime_dat %>% filter(str_detect(crime_date, "2024")) # 2388 - 95 = 2293


# remove NA locations and preparing location for OSM geocoding 
crime_dat <- crime_dat %>% 
  filter(!is.na(crime_location)) %>% 
  filter(!map_lgl(crime_location, ~length(.) == 0)) %>% # remov empt loc vec
  filter(crime_location != "Berlin") %>% # remov generic loc
  mutate(crime_location = if_else(
    str_detect(crime_location, ".*U-.* |.*S-.*"), 
    str_replace(crime_location, "U-|S-", ""), crime_location)) %>% 
  filter(!str_detect(crime_location, "BAB")) %>% # remov autobahn
  mutate(crime_location = str_remove_all(crime_location, "\\s+$")) %>%    
  mutate(crime_location = paste(crime_location, location, sep = ", ")) %>%   # add distr loc for geocoding accuracy
  distinct() # = 2055
  


# geocode 
crime_geo <- crime_dat %>% 
  geocode(crime_location, method = 'osm', limit = 1)

writexl::write_xlsx(crime_geo, "crime_geo.xlsx")


# generate geometry column after manually geocoding undeteced locations by OSM
crime_sf <- crime_geo %>%  filter(!is.na(lat)) %>% st_as_sf(coords = c("long", "lat"), crs = 4326) 


# remove crime locations outside Berlin
berlin_boroughs <- st_read("../data/berlin_bezirke.gpkg") %>% st_as_sf() %>% st_transform(crs = 4326)
berlin_bbox <- st_as_sfc(st_bbox(berlin_boroughs)) 
crime_sf <- crime_sf  %>% filter(as.vector(st_intersects(., berlin_bbox, sparse = FALSE)))



# raw crime points on Berlin basemap 
  geom_sf(data = berlin_boroughs) +
  geom_sf(data = crime_sf) +
  theme_void()


# save cleaned crime shp file
st_write(crime_sf, "../data/crime_sf.shp")

