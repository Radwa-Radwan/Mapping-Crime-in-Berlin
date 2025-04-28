if (!require("pacman")) install.packages("pacman")
pacman::p_load(dplyr,
               ggplot2,
               forcats,
               sf,
               units,
               spatstat,
               spatstat.geom,
               spdep,
               hms,
               lubridate,
               leaflet,
               mapview,
               showtext)


outlets <- st_read("../data/gis_osm_pois_free_1.shp") |> filter(fclass == "nightclub" | fclass == "bar" | fclass == "pub")|>
  st_transform(4326) |> select(fclass, geometry) 

clubs <- st_read("../data/nightclubs.shp") |> select(fclass, geometry) |> st_transform(4326) 

outlets <- rbind(outlets, clubs) |>  distinct(geometry, .keep_all = TRUE) |> st_transform(32633) 


crimes <- st_read("../data/crime_sf.shp") |> rename(report_id = reprt_d, crim_cat = crm_ctg, crim_loc = crm_lct ) |>
  select(report_id, crim_cat, crim_dt, crim_tm, crim_loc, geometry) |>
  st_transform(crs = st_crs(outlets)) 



# ------------------------ ncross analysis ---------------------------

outlets_coords <- st_coordinates(outlets)  # extract coords from outlets_sf
crimes_coords <- st_coordinates(crimes)   # extract coords from crimes_sf
head(outlets_coords) # just for inspection


window <- owin(xrange = range(c(outlets_coords[, 1], crimes_coords[, 1])),
                      yrange = range(c(outlets_coords[, 2], crimes_coords[, 2]))) # create a window based on both sf data coords


outlets_ppp <- ppp(x = outlets_coords[, 1], y = outlets_coords[, 2], window = window) # outlets ppp type object for nncross 
crimes_ppp <- ppp(x = crimes_coords[, 1], y = crimes_coords[, 2], window = window) # crimes ppp type object for nncross 


nn_dist <- nncross(crimes_ppp, outlets_ppp, k =1) # calculate  crime is main var of interest. Q Are crimes happening near outelts?

mean_dist <-  mean(nn_dist$dist)
cat("Average Distance between Crimes and Outlets" , round(mean_dist, 0), "meters")

distances <- nn_dist$dist
summary(distances) # summary stats

# statistical significance test -----------------

# random_crimes <- runifpoint(n = npoints(crimes_ppp), win = Window(crimes_ppp))
# random_dist <- nncross(random_crimes, outlets_ppp)$dist
# random_mean <- mean(random_dist)
# random_mean
# 
# n_simulations <- 5000
# mean_random_distances <- numeric(n_simulations)
# 
# 
# for (i in 1:n_simulations) {
#   random_crimes <- runifpoint(n = npoints(crimes_ppp), win = Window(crimes_ppp))
#   random_dist <- nncross(random_crimes, outlets_ppp)$dist
# 
#   # Store the mean distance for this simulation
#   mean_random_distances[i] <- mean(random_dist)
# }
# 
# # Calculate the p-value: the proportion of simulations where random distances are <= real mean distance
# p_value <- mean(mean_random_distances <= mean_dist)
# summary(mean_random_distances)
# 
# # Print the result
# cat("p-value: ", p_value, "\n")
# # 
# plot(random_crimes)

# -------------------------------------


#--------------------  analysis for selected distance 10 -300  --------------

min_dist <- 10
max_dist <- 200

nearest_outlets <- nn_dist$which

valid_indices <- which(distances >= min_dist & distances <= max_dist) # filter distances within boundary

crimes_neigboured <- crimes[valid_indices, ] 
crimes_neigboured_coords <- st_coordinates(crimes_neigboured)# filter crime coords matrix based on distance boundaries
# outlets_coords #  we already have it

nearest_outlets_coords <- outlets_coords[nearest_outlets[valid_indices], ] # filter close outlets within boundaries


edges_list <- lapply(seq_len(nrow(crimes_neigboured_coords)), function(i) {
  st_linestring(rbind(crimes_neigboured_coords[i, ], nearest_outlets_coords[i, ])) # create line string between the filtered point feature
})


edges_sf <- st_sf(geometry = st_sfc(edges_list), distance = distances[valid_indices], crs = st_crs(crimes)) # transform edges to sf obj


crime_perc <- (nrow(crimes_neigboured) / nrow(crimes)) * 100 # percentage of crimes within 10 to 200 m distance to outlets


# change crs for map plot
crimes  <- st_transform(crimes, 4326)
outlets <- st_transform(outlets, 4326)
edges_sf <- st_transform(edges_sf, 4326)


# leaflet map crime_outlet_map <- 

leaflet() %>%
  addProviderTiles(providers$CartoDB.Positron) %>% # base map - googlemaps
  addCircleMarkers(
    data = outlets,
    color = "blue",
    radius = 3,
    label = ~ fclass,
    group = "Outlets",
    fillOpacity = 0.7,
    stroke = FALSE) %>%
  addCircleMarkers(
    data = crimes,
                   color = "red", radius = 3,
                   label = ~crim_cat, group = "Crimes",
                   fillOpacity = 0.7, stroke = FALSE) %>% 
  addPolylines( data = edges_sf,
    color = "purple",
    weight = 2,
    opacity = 0.7,
    group = "Connections") %>%
  addLayersControl(
    overlayGroups = c("Outlets", "Crimes", "Connections"),
    options = layersControlOptions(collapsed = FALSE)) %>%
  addControl(html = sprintf("<strong>Nearest Neighbor Connections<br>%.2f%% of Crimes Connected (100–300m)</strong>", crime_perc),
    position = "topright") %>% 
  addLegend(
    position = "bottomright", 
    colors = c("red", "blue", "purple"),  
    labels = c("Crime", "Outlet", "Unweighted edges"),  
    title = "Feature type",  
    opacity = 1) 


mapshot(the_map, url = "../figures/map.html")


# ------------------ post analysis descriptives ---------------------

crimes_neigboured$crim_dt <- as.Date(crimes_neigboured$crim_dt, format = "%d/%m/%Y")


crimes_neigboured <- crimes_neigboured %>% 
  mutate(weekd = weekdays(crim_dt),
         weekd = factor(weekd, levels = c("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")))



# crime cat count per weekd
weekd_summary <- crimes_neigboured %>%
  st_drop_geometry() %>% 
  group_by(crim_cat, weekd) %>%
  summarise(total = n()) 

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
    strip.text = element_text(face = "bold", size = 12),
    plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
    plot.subtitle = element_text(size = 12),
    axis.text = element_text(size = 10,margin(t = 0, b = -5)),
    axis.title = element_text(size = 12),
    axis.text.y = element_text(colour = "black", size = 10)
  )


time_df <- crimes_neigboured %>% st_drop_geometry() %>% 
  select(report_id, crim_cat, crim_tm) %>% 
  filter(!is.na(crim_tm)) %>% 
  mutate(crim_tm = paste0(crim_tm, ":00")) %>% 
  mutate(crim_tm = as_hms(crim_tm)) %>% 
  group_by(crim_cat, crim_tm) %>%
  summarise(count = n(), .groups = "drop")

time_df$hour_shifted <- (hour(time_df$crim_tm) - 18) %% 24 # create a hour col with hours starting 18:00


ggplot(time_df, aes(x = hour_shifted, y = count)) +
  geom_smooth(method = "loess", span = 0.3, se = FALSE, color = "black", size = 0.5) + # smoothing
  scale_x_continuous(
    breaks = seq(0, 24, by = 2),
    labels = function(x) {
      # Generate labels starting from 6 PM (18:00)
      labels <- sprintf("%02d:00", (x + 18) %% 24)  # shift by 18 hours
      return(labels)
    },
    name = "Hour of Day (starting at 18:00)"
  ) +
  # labs(title = "Counts by Hour with Trend", x = "Hour of Day", y = "Count") +
  facet_wrap(~crim_cat, ncol = 2) +
  theme_get() +
  theme(
    axis.title.x = element_blank(),  # Set font for x-axis title
    axis.title.y = element_text(family = "Georgia"),  # Set font for y-axis title
    axis.text.x = element_text(family = "Georgia"),   # Set font for x-axis labels
    axis.text.y = element_text(family = "Georgia"),   # Set font for y-axis labels
    axis.ticks.y = element_blank(),
    plot.title = element_text(family = "Georgia")  # Set font for plot title
  )



