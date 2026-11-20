#Identifying which genera are in the countries and seeing if this is a factor affecting the percentage that is unidentified

library(DBI)
library(duckdb)
library(dplyr)
library(ggplot2)
library(ggrepel)

file_identified <- "~/Kew_2_Team_Challenge/parsegbif_sem_identificacao_2025 v2/top100_registros_identificados_campos_analise.csv"
file_unidentified <- "~/Kew_2_Team_Challenge/parsegbif_sem_identificacao_2025 v2/top100_registros_nao_identificados_campos_analise.csv"

# Only create a connection if you don't already have one
if (!exists("con") || !DBI::dbIsValid(con)) {
  con <- dbConnect(duckdb::duckdb())
}

genus_country_summary <- dbGetQuery(
  con,
  "
  WITH combined AS (

    -- Species-level identified specimens
    SELECT
      UPPER(TRIM(Ctrl_countryCode)) AS country,
      UPPER(TRIM(genus)) AS genus,
      1 AS identified,
      0 AS unidentified
    FROM read_csv(
      ?,
      all_varchar = true,
      nullstr = ''
    )

    UNION ALL

    -- Genus-only identified specimens
    SELECT
      UPPER(TRIM(Ctrl_countryCode)) AS country,
      UPPER(TRIM(genus)) AS genus,
      0 AS identified,
      1 AS unidentified
    FROM read_csv(
      ?,
      all_varchar = true,
      nullstr = ''
    )

  )

  SELECT
    country,
    genus,
    SUM(identified) AS identified,
    SUM(unidentified) AS unidentified,
    COUNT(*) AS total,
    ROUND(
      100.0 * SUM(unidentified) / COUNT(*),
      2
    ) AS percentageUnidentified

  FROM combined

  WHERE regexp_full_match(country, '[A-Z]{2}')
    AND genus IS NOT NULL
    AND genus != ''

  GROUP BY country, genus
  ORDER BY country, unidentified DESC
  ",
  params = list(
    path.expand(file_identified),
    path.expand(file_unidentified)
  )
)

View(genus_country_summary)

#Calculating how common each genus is within a country and adding to the data frame


genus_country_summary <- genus_country_summary %>%
  group_by(country) %>%
  mutate(
    country_total = sum(total),
    
    genus_proportion =
      100 * total / country_total
  ) %>%
  ungroup()

View(genus_country_summary)

#Calculating the enrichment of genera within a country, by comparing to the global dataset 

global_genus <- genus_country_summary %>%
  group_by(genus) %>%
  summarise(
    global_total = sum(total),
    .groups = "drop"
  ) %>%
  mutate(
    global_proportion = global_total/sum(global_total)
  )

genus_country_enrichment <- genus_country_summary %>%
  left_join(global_genus, by = "genus") %>%
  mutate(
    country_proportion = genus_proportion / 100,
    enrichment = country_proportion / global_proportion
  )

View(genus_country_enrichment)

#Investigating peru as an example first with a minimum of 100 records for the genus to avoid large ratios based on few records


peru_genera <- genus_country_enrichment %>%
  filter(
    country == "PE",
    total >= 100
  ) %>%
  arrange(desc(enrichment))

View(peru_genera)



ggplot(peru_genera, aes(
  x = enrichment,
  y = percentageUnidentified,
  size = total
)) +
  geom_point(
    colour = "#B49AD6",
    alpha = 0.7
  ) +
  geom_text_repel(
    aes(label = genus),
    colour = "#333333",
    size = 3,
    max.overlaps = 15
  ) +
  scale_x_log10() +
  scale_size_continuous(
    name = "Specimen count"
  ) +
  labs(
    title = "Genus Enrichment and Identification Gaps in Peru",
    subtitle = "Top 100 species-rich genera",
    x = "Genus enrichment relative to global records",
    y = "Unidentified Specimens (%)"
  ) +
  theme_minimal()

#Does enrichment correlate with percentage unidentified? 

cor.test(
  peru_genera$enrichment,
  peru_genera$percentageUnidentified,
  method = "spearman",
  exact = FALSE
)

#Positive correlation but not statistically significant. Now seeing if all genera in peru have a higher unidentified than would be expected based on the global data

global_genus_rates <- genus_country_summary %>%
  group_by(genus) %>%
  summarise(
    global_unidentified = sum(unidentified),
    global_total = sum(total),
    .groups = "drop"
  )

peru_comparison <- genus_country_summary %>%
  filter(country == "PE") %>%
  left_join(global_genus_rates, by = "genus") %>%
  mutate(
    outside_total = global_total - total,
    outside_unidentified = 
      global_unidentified - unidentified,
    outside_rate = if_else(
      outside_total > 0, 
      outside_unidentified / outside_total,
      NA_real_
    ),
    expected_unidentified = total * outside_rate
  ) %>%
  filter(!is.na(outside_rate))

View(peru_comparison)


peru_results <- peru_comparison %>%
  summarise(
    observed_unidentified = sum(unidentified),
    expected_unidentified = sum(expected_unidentified),
    total_specimens = sum(total),
    
    observed_percentage =
      100 * observed_unidentified / total_specimens,
    
    expected_percentage =
      100 * expected_unidentified / total_specimens
  )

print(peru_results)


#Expanding the country analysis observed versus expected to all the countries in the dataset 


global_genus_rates <- genus_country_summary %>%
  group_by(genus) %>%
  summarise(
    global_unidentified = sum(unidentified),
    global_total = sum(total),
    .groups = "drop"
  )

#Calculate expected counts for every country
country_genus_expected <- genus_country_summary %>%
  left_join(global_genus_rates, by = "genus") %>%
  mutate(
    # Records from the same genus outside this country
    outside_total = global_total - total,
    
    outside_unidentified =
      global_unidentified - unidentified,
    
    # Unidentified rate outside this country
    outside_rate = if_else(
      outside_total > 0,
      outside_unidentified / outside_total,
      NA_real_
    ),
    
    # Expected unidentified records
    expected_unidentified = total * outside_rate
  )

#Summarise by country into a data frame

country_adjusted <- country_genus_expected %>%
  group_by(country) %>%
  summarise(
    total_specimens = sum(total),
    
    covered_specimens = sum(
      total[!is.na(outside_rate)]
    ),
    
    observed_unidentified = sum(
      unidentified[!is.na(outside_rate)]
    ),
    
    expected_unidentified = sum(
      expected_unidentified,
      na.rm = TRUE
    ),
    
    .groups = "drop"
  ) %>%
  mutate(
    coverage = 100 * covered_specimens / total_specimens,
    
    observed_percentage =
      100 * observed_unidentified / covered_specimens,
    
    expected_percentage =
      100 * expected_unidentified / covered_specimens,
    
    excess_percentage =
      observed_percentage - expected_percentage,
    
    observed_expected_ratio = if_else(
      expected_unidentified > 0,
      observed_unidentified / expected_unidentified,
      NA_real_
    )
  ) %>%
  filter(
    covered_specimens >= 1000,
    coverage >= 95
  ) %>%
  arrange(desc(excess_percentage))

View(country_adjusted)

#Visualising the country_adjusted differences 


top20_excess <- country_adjusted %>%
  slice_max(
    excess_percentage,
    n = 20,
    with_ties = FALSE
  )

ggplot(top20_excess, aes(
  x = reorder(country, excess_percentage),
  y = excess_percentage,
  fill = excess_percentage
)) +
  geom_col(width = 0.8) +
  coord_flip() +
  scale_fill_gradientn(
    colours = c(
      "#F8E7A2",
      "#F6BEA6",
      "#EFA6C8",
      "#B49AD6"
    ),
    name = "Excess (%)"
  ) +
  labs(
    title = "Countries with Higher Unidentified Rates Than Expected",
    subtitle = "Adjusted for genus composition",
    x = "Country",
    y = "Observed minus expected (percentage points)"
  ) +
  theme_minimal()
print(top20_excess)


#Showing the best 20 countries


bottom20_excess <- country_adjusted %>%
  slice_min(
    excess_percentage,
    n = 20,
    with_ties = FALSE
  )

ggplot(bottom20_excess, aes(
  x = reorder(country, excess_percentage),
  y = excess_percentage
)) +
  geom_col(fill = "#278C70") +
  coord_flip() +
  labs(
    title = "Countries with Lower Unidentified Rates Than Expected",
    subtitle = "Adjusted for genus composition",
    x = "Country",
    y = "Observed minus expected (percentage points)"
  ) +
  theme_minimal()
print(bottom20_excess)

#Showing all the countries
# Select countries with the largest differences
top_positive <- country_adjusted_plot %>%
  slice_max(excess_percentage, n = 15)

top_negative <- country_adjusted_plot %>%
  slice_min(excess_percentage, n = 15)

countries_to_label <- bind_rows(
  top_positive,
  top_negative
) %>%
  distinct(country, .keep_all = TRUE)

# Plot all countries
p_adjusted <- ggplot(country_adjusted_plot, aes(
  x = excess_percentage,
  y = reorder(country, excess_percentage),
  colour = difference_group
)) +
  geom_vline(
    xintercept = 0,
    linetype = "dashed",
    colour = "#555555"
  ) +
  geom_point(
    size = 2.5,
    alpha = 0.85
  ) +
  geom_text_repel(
    data = countries_to_label,
    aes(label = country),
    colour = "#333333",
    size = 3.5,
    fontface = "bold",
    max.overlaps = Inf,
    box.padding = 0.4,
    point.padding = 0.3,
    show.legend = FALSE
  ) +
  scale_colour_manual(
    values = c(
      "Higher than expected" = "#D65A91",
      "Lower than expected" = "#278C70"
    ),
    name = "Identification gap"
  ) +
  labs(
    title = "Genus-Adjusted Identification Gaps by Country",
    subtitle = "Top 100 species-rich genera",
    x = "Observed minus expected (percentage points)",
    y = NULL
  ) +
  theme_minimal() +
  theme(
    axis.text.y = element_blank(),
    axis.ticks.y = element_blank(),
    panel.grid.major.y = element_blank(),
    plot.title = element_text(
      size = 16,
      face = "bold"
    ),
    legend.position = "bottom"
  )

print(p_adjusted)

#Trying a ranked dot plot
country_ranked <- country_adjusted_plot %>%
  arrange(excess_percentage) %>%
  mutate(rank = row_number())

ggplot(country_ranked, aes(
  x = rank,
  y = excess_percentage,
  colour = difference_group
)) +
  geom_hline(
    yintercept = 0,
    linetype = "dashed",
    colour = "#555555"
  ) +
  geom_point(size = 2.5, alpha = 0.8) +
  scale_colour_manual(
    values = c(
      "Higher than expected" = "#D65A91",
      "Lower than expected" = "#278C70"
    )
  ) +
  labs(
    title = "Global Distribution of Genus-Adjusted Identification Gaps",
    subtitle = "Countries ranked from lowest to highest adjusted gap",
    x = "Country rank",
    y = "Observed minus expected (percentage points)",
    colour = "Identification gap"
  ) +
  theme_minimal()
