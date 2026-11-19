library(sf)
library(rnaturalearth)
library(dplyr)
library(ggplot2)
library(patchwork)


# Get world country boundaries
world <- ne_countries(
  scale = "medium",
  returnclass = "sf"
)


# Clean country codes
country_map_data <- country_summary %>%
  filter(grepl("^[A-Z]{2}$", country)) %>%
  mutate(country = toupper(country))

# Join GBIF results to world boundaries
world_data <- world %>%
  left_join(
    country_map_data,
    by = c("iso_a2_eh" = "country")
  )

# Check the results
head(world_data)

#Creating a map based on percentage unidentified

map_percentage <- ggplot(world_data) +
  geom_sf(
    aes(fill = percentageUnidentified),
    colour = "white",
    linewidth = 0.1
  ) +
  scale_fill_gradientn(
    colours = c(
      "#A8D5BA",  # Sage green
      "#F8E7A2",  # Butter yellow
      "#F6BEA6",  # Peach
      "#EFA6C8",  # Pastel pink
      "#B49AD6"
    ),
    na.value = "#E5E5E5",
    name = "Unidentified (%)"
  ) +
  coord_sf(expand = FALSE) +
  labs(
    title = "Percentage of Unidentified Specimens",
    subtitle = "Top 100 species-rich genera"
  ) +
  theme_void() +
  theme(
    plot.title = element_text(
      size = 15,
      face = "bold"
    ),
    legend.position = "bottom"
  )

print(map_percentage)
