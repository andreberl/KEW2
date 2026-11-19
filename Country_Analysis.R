
library(DBI)
library(duckdb)
# Only create a connection if you don't already have one
if (!exists("con") || !DBI::dbIsValid(con)) {
  con <- dbConnect(duckdb::duckdb())
}



country_summary <- dbGetQuery(
  con,
  "
  WITH combined AS (

    -- Species-level identified records
    SELECT
      UPPER(TRIM(Ctrl_countryCode)) AS country,
      1 AS identified,
      0 AS unidentified
    FROM read_csv(?, all_varchar = true)

    UNION ALL

    -- Genus-only unidentified records
    SELECT
      UPPER(TRIM(Ctrl_countryCode)) AS country,
      0 AS identified,
      1 AS unidentified
    FROM read_csv(?, all_varchar = true)

  )

  SELECT
    country,
    SUM(identified) AS identified,
    SUM(unidentified) AS unidentified,
    COUNT(*) AS total,
    ROUND(
      100.0 * SUM(unidentified) / COUNT(*),
      2
    ) AS percentageUnidentified

  FROM combined

  WHERE country IS NOT NULL
    AND country != ''

  GROUP BY country
  ORDER BY percentageUnidentified DESC
  ",
  params = list(
    path.expand(file_identified),
    path.expand(file_unidentified)
  )
)

View(country_summary)

#Cleaning the data because the first row is an invalid country

country_filtered <- country_summary %>%
  filter(
    grepl("^[A-Z]{2}$", country),
    total >= 1000
  ) %>%
  arrange(desc(percentageUnidentified))

View(country_filtered)

# Select the top 20
top20_countries <- country_filtered %>%
  slice_head(n = 20)

# Plot
ggplot(top20_countries, aes(
  x = reorder(country, percentageUnidentified),
  y = percentageUnidentified,
  fill = percentageUnidentified
)) +
  geom_col(width = 0.8) +
  coord_flip() +
  scale_fill_gradientn(
    colours = c(
      "#A8D5BA",
      "#F8E7A2",
      "#F6BEA6",
      "#EFA6C8",
      "#B49AD6"
    ),
    name = "Unidentified (%)"
  ) +
  labs(
    title = "Geographical Variation in Taxonomic Identification",
    subtitle = "Top 100 species-rich genera | Minimum 1,000 specimens",
    x = "Country Code",
    y = "Specimens Unidentified to Species Level (%)"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 15, face = "bold"),
    axis.text.y = element_text(size = 10),
    panel.grid.major.y = element_blank()
  )

#Dealing with absolute number identified because this is still important for the global records


# Top 20 by percentage unidentified
top20_percentage <- country_filtered %>%
  arrange(desc(percentageUnidentified)) %>%
  slice_head(n = 20)

# Top 20 by absolute number unidentified
top20_absolute <- country_filtered %>%
  arrange(desc(unidentified)) %>%
  slice_head(n = 20)

View(top20_percentage)
View(top20_absolute)

#Scatter plot comparing percentage unidentifeid and absolut number, also colouring based on priority, e.g. if they are high in both, high in one or the other, or low in both


library(dplyr)
library(ggplot2)
library(ggrepel)

# Calculate 75th percentile thresholds
count_threshold <- quantile(
  country_filtered$unidentified,
  0.75,
  na.rm = TRUE
)

percentage_threshold <- quantile(
  country_filtered$percentageUnidentified,
  0.75,
  na.rm = TRUE
)

# Categorise countries
country_plot <- country_filtered %>%
  mutate(
    priority_group = case_when(
      unidentified >= count_threshold &
        percentageUnidentified >= percentage_threshold ~
        "High in both",
      
      unidentified >= count_threshold ~
        "High count",
      
      percentageUnidentified >= percentage_threshold ~
        "High percentage",
      
      TRUE ~ "Other countries"
    )
  )

# Check how many countries fall in each group
table(country_plot$priority_group)


p_country <- ggplot(country_plot, aes(
  x = unidentified,
  y = percentageUnidentified
  )) +
  
  # Background countries
  geom_point(
    data = country_plot %>%
      filter(priority_group == "Other countries"),
    colour = "#B8BCC4",
    size = 2.5,
    alpha = 0.45
  ) +
  
  # Highlighted countries
  geom_point(
    data = country_plot %>%
      filter(priority_group != "Other countries"),
    aes(colour = priority_group),
    size = 3.8,
    alpha = 0.95
  ) +
  
  # Country labels
  geom_text_repel(
    data = country_plot %>%
      filter(priority_group == "High in both"),
    aes(label = country),
    colour = "#333333",
    size = 3.8,
    fontface = "bold",
    max.overlaps = Inf,
    box.padding = 0.5,
    point.padding = 0.3,
    segment.colour = "#999999",
    show.legend = FALSE
  ) +
  
  # Higher contrast palette
  scale_colour_manual(
    values = c(
      "High in both" = "#D65A91",
      "High count" = "#278C70",
      "High percentage" = "#8461C5"
    ),
    name = "Identification gap category"
  ) +
  
  scale_x_log10(
    labels = scales::label_comma()
  ) +
  
  labs(
    title = "Geographical Identification Gaps",
    subtitle = "Top 100 species-rich genera",
    x = "Number of Unidentified Specimens (log scale)",
    y = "Unidentified Specimens (%)"
  ) +
  
  theme_minimal(base_size = 12) +
  
  theme(
    plot.title = element_text(
      size = 17,
      face = "bold"
    ),
    plot.subtitle = element_text(size = 12),
    axis.title = element_text(size = 12),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(
      colour = "#E8E8E8"
    ),
    legend.position = "right"
  )

print(p_country)


