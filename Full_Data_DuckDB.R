
library(DBI)
library(duckdb)

con <- dbConnect(duckdb::duckdb())


# File containing species-level identified specimens
file_identified <- "~/Kew_2_Team_Challenge/parsegbif_sem_identificacao_2025 v2/top100_registros_identificados_campos_analise.csv"

# File containing genus-level unidentified specimens
file_unidentified <- "~/Kew_2_Team_Challenge/parsegbif_sem_identificacao_2025 v2/top100_registros_nao_identificados_campos_analise.csv"

# Check that both files exist
file.exists(file_identified)
file.exists(file_unidentified)




# Preview only 10 rows
unidentified_preview <- dbGetQuery(
  con,
  "SELECT *
   FROM read_csv(
     ?,
     all_varchar = true
   )
   LIMIT 10",
  params = list(path.expand(file_unidentified))
)

View(unidentified_preview)

#Preview identified

identified_preview <- dbGetQuery(
  con,
  "SELECT *
   FROM read_csv(
     ?,
     all_varchar = true
   )
   LIMIT 10",
  params = list(path.expand(file_identified))
)

View(identified_preview)




# Count identified specimens
n_identified <- dbGetQuery(
  con,
  "SELECT COUNT(*) AS total
   FROM read_csv(?, all_varchar = true)",
  params = list(path.expand(file_identified))
)

# Count unidentified specimens
n_unidentified <- dbGetQuery(
  con,
  "SELECT COUNT(*) AS total
   FROM read_csv(?, all_varchar = true)",
  params = list(path.expand(file_unidentified))
)

print(n_identified)
print(n_unidentified)

#Percent unidentified
total <- n_identified$total + n_unidentified$total

percentage_unidentified <-
  (n_unidentified$total / total) * 100

print(percentage_unidentified)

#Grouping the unidentified counts by genus, like the top100_genera dataset

genus_counts <- dbGetQuery(
  con,
  "SELECT
     UPPER(TRIM(genus)) AS genus,
     COUNT(*) AS unidentified_specimens
   FROM read_csv(
     ?,
     all_varchar = true
   )
   WHERE genus IS NOT NULL
     AND TRIM(genus) != ''
   GROUP BY UPPER(TRIM(genus))
   ORDER BY unidentified_specimens DESC",
  params = list(path.expand(file_unidentified))
)

genus_counts$genus <- paste0(
  substr(genus_counts$genus, 1, 1),
  tolower(substr(genus_counts$genus, 2,
                 nchar(genus_counts$genus)))
)

View(genus_counts)

#Viewing the identified counts by genus
id_genus_counts <- dbGetQuery(
  con,
  "SELECT
     UPPER(TRIM(genus)) AS genus,
     COUNT(*) AS unidentified_specimens
   FROM read_csv(
     ?,
     all_varchar = true
   )
   WHERE genus IS NOT NULL
     AND TRIM(genus) != ''
   GROUP BY UPPER(TRIM(genus))
   ORDER BY unidentified_specimens DESC",
  params = list(path.expand(file_identified))
)

id_genus_counts$genus <- paste0(
  substr(id_genus_counts$genus, 1, 1),
  tolower(substr(id_genus_counts$genus, 2,
                 nchar(id_genus_counts$genus)))
)

View(id_genus_counts)

