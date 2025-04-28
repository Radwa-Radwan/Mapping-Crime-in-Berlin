if (!require("pacman")) install.packages("pacman")
pacman::p_load(dplyr,
               ggplot2,
               sf,
               ggspatial,
               forcats,
               hms,
               lubridate,
               extrafont,
               showtext,
               ggthemes)


showtext_auto() 
font_import() # takes some time


crime_sf <- st_read("../data/crimes.shp", quiet = TRUE) |>  st_transform(crs = 4326) |> # remove quiet to check metadata 
  rename(report_id = reprt_d,
         crim_cat = crm_ctg,
         crim_loc = crm_lct)

bbox_map <- st_bbox(berlin_boroughs) 
crime_sf <- st_crop(crime_sf, bbox_map)


crime_sf$crim_dt <- as.Date(crime_sf$crim_dt, format = "%d/%m/%Y") # change date format

crime_sf <- crime_sf %>% # create factor col for weekdays
  mutate(weekd = weekdays(crim_dt),
         weekd = factor(weekd, levels = c("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")))



# crime cat count per weekd
weekd_summary <- crime_sf %>%
  st_drop_geometry() %>% 
  group_by(crim_cat, weekd) %>%
  summarise(total = n(), .groups = "drop") %>% 
  filter(!is.na(weekd))


ggplot(weekd_summary, aes(x = weekd, y = total, fill = weekd)) +
  geom_col(show.legend = FALSE, fill = "steelblue", width = 0.5) +
  facet_wrap(~crim_cat, ncol = 2, scales = "free_y") +
  labs(x = "", y = "") +
  coord_flip() +
  theme_minimal() +
  theme(
  text = element_text(family = "Georgia"),
  panel.grid.major.y = element_blank(),
  panel.grid.minor = element_blank(),
  panel.spacing = unit(1, "lines"),
  strip.text = element_text(face = "bold", size = 16),
  plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
  plot.subtitle = element_text(size = 12),
  axis.text = element_text(size = 12,margin(t = 0, b = -5)),
  axis.title = element_text(size = 12),
  axis.text.y = element_text(colour = "black", size = 12),
  axis.title.x = element_text(colour = "black", size = 6)
)


# crime time distribution
time_df <- crime_sf %>% st_drop_geometry() %>% 
  select(report_id, crim_cat, crim_tm) %>% 
  filter(!is.na(crim_tm)) %>% # remove non valid rows, 286
  mutate(crim_tm = paste0(crim_tm, ":00"),   
         crim_tm = hms::as_hms(crim_tm))    %>% 
  group_by(crim_cat ,crim_tm) %>% 
  summarise(count = n(), .groups = "drop") 

time_df$hour_shifted <- (hour(time_df$crim_tm) - 18) %% 24 # create a hour col with hours starting 18:00


ggplot(time_df, aes(x = hour_shifted, y = count)) +
  # geom_line(color = "grey", size = 1) +
  geom_smooth(method = "loess", span = 0.3, se = FALSE, color = "black", size = 0.5) + # smoothing
  scale_x_continuous(
    breaks = seq(0, 24, by = 2),
    labels = function(x) {
      # Generate labels starting from 6 PM (18:00)
      labels <- sprintf("%02d:00", (x + 18) %% 24)  # shift by 18 hours
      return(labels)
    },

  ) +
  # labs(title = "Counts by Hour", x = "Hour of Day", y = "Count") +
  facet_wrap(~crim_cat, ncol = 2) +
  theme_get() +
  theme(
    axis.title.x = element_blank(),  # Set font for x-axis title
    axis.title.y = element_text(family = "Georgia"),  
    axis.text.x = element_text(family = "Georgia", face = "bold", color = "black"),   
    axis.text.y = element_text(family = "Georgia"),   
    axis.ticks.y = element_blank(),
    plot.title = element_text(family = "Georgia"),
    strip.text = element_text(size = 16, face = "bold", color = "black")
  )





# crime count per category
crime_sf %>% 
  group_by(crim_cat) %>% 
  summarise(total = n()) %>% 
  ungroup() %>% 
  ggplot(aes(x = fct_reorder(crim_cat, total), y = total)) +
  geom_col(fill = "#1f77b4", , width = 0.5) +
  geom_text(aes(label = total), vjust = 0.3, hjust = 1.2,
            color = "black", size = 5.5, fontface = "bold") +
  coord_flip() +
  labs(x = NULL) +
  theme(axis.text.y = element_text(face = "bold", size = 16, family = "Georgia", color = "black"),
        axis.ticks.y = element_blank(),
        axis.ticks.x = element_blank(),  
        axis.title.x = element_blank()) + 
  scale_y_discrete(breaks = NULL, labels = NULL)
  

# maps ------------------------------

berlin_boroughs <- st_read("../data/berlin_bezirke.gpkg", quiet = TRUE) |> st_as_sf() |> st_transform(crs = 4326)

bbox_map <- st_bbox(berlin_boroughs) 
points_filtered <- st_crop(crime_sf, bbox_map)

ggplot() +
  geom_sf(data = berlin_boroughs, fill = "black", linewidth = 0.2) +
  geom_sf(data = points_filtered, aes(color = "red"), size = 0.5) +
  # annotation_scale(location = "bl", width_hint = 0.4) +
  # annotation_north_arrow(location = "tl", which_north = "true", style = north_arrow_nautical) +
  # labs(title = "Crime Incidents in Berlin 2024", color = "Crime Incidents") +
  theme_void() +
  theme(legend.position = "none")


outlets <- st_read("../data/gis_osm_pois_free_1.shp") |> filter(fclass == "nightclub" | fclass == "bar" | fclass == "pub")|>
  st_transform(4326) |> select(fclass, geometry) 

clubs <- st_read("../data/nightclubs.shp") |> select(fclass, geometry) |> st_transform(4326) 

outlets <- rbind(outlets, clubs) |>  distinct(geometry, .keep_all = TRUE) 

bbox_map <- st_bbox(berlin_boroughs) 
outlets_filtered <- st_crop(outlets, bbox_map)

ggplot() +
  geom_sf(data = berlin_boroughs, fill = "black", linewidth = 0.2) +
  geom_sf(data = outlets , color = "#FF8C00", size = 0.5) +
  # annotation_scale(location = "bl", width_hint = 0.4) +
  # annotation_north_arrow(location = "tl", which_north = "true", style = north_arrow_nautical) +
  # labs(title = "Crime Incidents in Berlin 2024", color = "Crime Incidents") +
  theme_void() +
  theme(legend.position = "none")

  