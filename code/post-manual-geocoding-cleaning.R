library(readxl)

crimes <- read_excel("../data/crime_geo.xlsx") %>% mutate(long = as.character(long)) %>%    mutate(
  long= if_else(
    stringr::str_detect(lat, ","),
    sub("^[^,]*,", "", lat),
    long
  ),
  lat = sub(",.*$", "", lat)  # keep only first value
) %>%
  mutate(lat = as.numeric(lat)) %>% mutate(long = as.numeric(long))

crimes <- crimes %>%  filter(!is.na(long)) %>% st_as_sf(coords = c("long", "lat"), crs = 4326) # 1955

st_write(crimes, "../data/crimes.shp")