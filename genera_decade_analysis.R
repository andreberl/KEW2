#Looking at the effect of both genus composition and collection decade on the unidentified composition per country



library(DBI)
library(duckdb)
library(dplyr)

#Creating a dataframe with duckDB with the number of identified and unidentified specimens per country, genus, and decade
#I saved as csv so in future can do country_genus_decade <- read.csv("country_genus_decade.csv") to load it in without having to run the query again

country_genus_decade <- dbGetQuery(
  con,
  "
  WITH combined AS (

    -- Species-level identified specimens
    SELECT
      UPPER(TRIM(Ctrl_countryCode)) AS country,
      UPPER(TRIM(genus)) AS genus,
      TRY_CAST(Ctrl_year AS INTEGER) AS year,
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
      TRY_CAST(Ctrl_year AS INTEGER) AS year,
      0 AS identified,
      1 AS unidentified
    FROM read_csv(
      ?,
      all_varchar = true,
      nullstr = ''
    )

  ),

  cleaned AS (
    SELECT
      country,
      genus,
      FLOOR(year / 10) * 10 AS decade,
      identified,
      unidentified
    FROM combined
    WHERE regexp_full_match(country, '[A-Z]{2}')
      AND genus IS NOT NULL
      AND genus != ''
      AND year BETWEEN 1700 AND 2025
  )

  SELECT
    country,
    genus,
    decade,
    SUM(identified) AS identified,
    SUM(unidentified) AS unidentified,
    COUNT(*) AS total

  FROM cleaned

  GROUP BY country, genus, decade
  ORDER BY country, genus, decade
  ",
  params = list(
    path.expand(file_identified),
    path.expand(file_unidentified)
  )
)

View(country_genus_decade)

#Calculating expected unidentified specimens for each genus decade combination

# Global counts for each genus and decade
global_genus_decade <- country_genus_decade %>%
  group_by(genus, decade) %>%
  summarise(
    global_unidentified = sum(unidentified),
    global_total = sum(total),
    .groups = "drop"
  )

# Calculate expected unidentified counts
country_decade_expected <- country_genus_decade %>%
  left_join(
    global_genus_decade,
    by = c("genus", "decade")
  ) %>%
  mutate(
    outside_total = global_total - total,
    
    outside_unidentified =
      global_unidentified - unidentified,
    
    outside_rate = if_else(
      outside_total > 0,
      outside_unidentified / outside_total,
      NA_real_
    ),
    
    expected_unidentified =
      total * outside_rate
  )

#Summarising the adjusted results by country 

country_adjusted_decade <- country_decade_expected %>%
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
    coverage =
      100 * covered_specimens / total_specimens,
    
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

View(country_adjusted_decade)

#Comparing old and new adjustmenst i.e comparing between just genera adjusted and genera-decade adjusted

comparison <- country_adjusted %>%
  select(
    country,
    genus_only_excess = excess_percentage
  ) %>%
  inner_join(
    country_adjusted_decade %>%
      select(
        country,
        genus_decade_excess = excess_percentage
      ),
    by = "country"
  ) %>%
  mutate(
    change =
      genus_decade_excess - genus_only_excess
  ) %>%
  arrange(desc(genus_only_excess))

View(comparison)

#Visualising the comparison

library(ggplot2)

ggplot(comparison, aes(
  x = genus_only_excess,
  y = genus_decade_excess
)) +
  geom_abline(
    slope = 1,
    intercept = 0,
    linetype = "dashed",
    colour = "#777777"
  ) +
  geom_point(
    colour = "#B49AD6",
    size = 3,
    alpha = 0.75
  ) +
  labs(
    title = "Effect of Collection Decade Adjustment",
    subtitle = "Top 100 species-rich genera",
    x = "Genus-adjusted gap (percentage points)",
    y = "Genus + decade-adjusted gap (percentage points)"
  ) +
  theme_minimal()



#quantifying the difference that the decade adjustment makes


library(dplyr)

comparison %>%
  summarise(
    mean_change = mean(change),
    mean_absolute_change = mean(abs(change)),
    median_absolute_change = median(abs(change)),
    maximum_absolute_change = max(abs(change)),
    correlation = cor(
      genus_only_excess,
      genus_decade_excess,
      method = "pearson"
    )
  )


comparison %>%
  mutate(
    absolute_change = abs(change)
  ) %>%
  arrange(desc(absolute_change)) %>%
  slice_head(n = 15)



