#Analysing the data based on collection year

library(DBI)
library(duckdb)

# Only create a connection if you don't already have one
if (!exists("con") || !DBI::dbIsValid(con)) {
  con <- dbConnect(duckdb::duckdb())
}

# Species-level identified records
file_identified <- "~/Kew_2_Team_Challenge/parsegbif_sem_identificacao_2025 v2/top100_registros_identificados_campos_analise.csv"

# Genus-only unidentified records
file_unidentified <- "~/Kew_2_Team_Challenge/parsegbif_sem_identificacao_2025 v2/top100_registros_nao_identificados_campos_analise.csv"

# Check both files exist
file.exists(file_identified)
file.exists(file_unidentified)


genus_year_summary <- dbGetQuery(
  con,
  "
  WITH combined AS (

    -- Identified specimens
    SELECT
      UPPER(TRIM(genus)) AS genus,
      TRY_CAST(Ctrl_year AS INTEGER) AS year,
      1 AS identified,
      0 AS unidentified
    FROM read_csv(?, all_varchar = true)

    UNION ALL

    -- Unidentified specimens
    SELECT
      UPPER(TRIM(genus)) AS genus,
      TRY_CAST(Ctrl_year AS INTEGER) AS year,
      0 AS identified,
      1 AS unidentified
    FROM read_csv(?, all_varchar = true)

  )

  SELECT
    genus,
    year,
    SUM(identified) AS identified,
    SUM(unidentified) AS unidentified,
    COUNT(*) AS total,
    ROUND(
      100.0 * SUM(unidentified) / COUNT(*),
      2
    ) AS percentageUnidentified

  FROM combined

  WHERE genus IS NOT NULL
    AND genus != ''
    AND year BETWEEN 1700 AND 2026

  GROUP BY genus, year
  ORDER BY genus, year
  ",
  params = list(
    path.expand(file_identified),
    path.expand(file_unidentified)
  )
)

View(genus_year_summary)

#Grouping by year

library(dplyr)
library(ggplot2)

year_summary <- genus_year_summary %>%
  group_by(year) %>%
  summarise(
    identified = sum(identified),
    unidentified = sum(unidentified),
    total = sum(total),
    percentageUnidentified =
      100 * unidentified / total,
    .groups = "drop"
  )

head(year_summary)

#Creating a graph based on year and percentage identified

max_pct <- max(year_summary$percentageUnidentified)

ggplot(year_summary, aes(
  x = year, 
  y = percentageUnidentified,
  fill = percentageUnidentified
)) +
  geom_col(width = 0.85) +
  coord_flip() +
  scale_fill_gradientn(
    colours = c(
      "#A8D5BA",  # Sage green
      "#F8E7A2",  # Butter yellow
      "#F6BEA6",  # Peach
      "#EFA6C8",  # Pastel pink
      "#B49AD6"   # Lavender
    ),
    limits = c(0, max_pct),
    name = "Unidentified (%)"
  ) +
  scale_y_continuous(
    limits = c(0, ceiling(max_pct / 5) * 5),
    breaks = seq(0, ceiling(max_pct / 5) * 5, by = 5),
    expand = expansion(mult = c(0, 0.02))
  ) +
  coord_flip() +
  labs(
    title = "Percentage of Unidentified Speciment Per Year",
    subtitle = "Top 100 genera",
    x = "Year",
    y = "Percentage Unidentified (%)"
  ) +
  theme_minimal() +
  theme(
    axis.text.y = element_text(size = 6),
    axis.text.x = element_text(size = 10),
    plot.title = element_text(size = 16, face = "bold"),
    plot.subtitle = element_text(size = 11),
    panel.grid.major.y = element_blank()
  )


#Line graph 



library(ggplot2)

ggplot(year_summary, aes(
  x = year,
  y = percentageUnidentified
)) +
  geom_line(
    colour = "#B49AD6",
    linewidth = 0.6,
    alpha = 0.5
  ) +
  geom_smooth(
    aes(weight = total),
    method = "loess",
    span = 0.3,
    colour = "#EFA6C8",
    fill = "#F8D8E8",
    linewidth = 1.2,
    se = TRUE
  ) +
  labs(
    title = "Changes in Taxonomic Identification Over Time",
    subtitle = "Top 100 species-rich genera",
    x = "Collection Year",
    y = "Specimens Unidentified to Species Level (%)"
  ) +
  theme_minimal()
