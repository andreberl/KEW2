
library(ggplot2)

# Find the maximum percentage
max_pct <- max(top100_genera$percentageUnidentified,
               na.rm = TRUE)
#Creating a plot of the genera based on their percentage unidentified
p <- ggplot(top100_genera, aes(
  x = reorder(genus, percentageUnidentified),
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
    title = "Percentage of Unidentified Genera",
    subtitle = "Top 100 genera",
    x = "Genus",
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

print(p)

#chi squared test to see if there is a significant difference between genera

# Create a contingency table
counts <- as.matrix(
  top100_genera[, c(
    "total_specimens_identificados",
    "total_specimens_nao_identificados"
  )]
)

# Add genus names
rownames(counts) <- top100_genera$genus

# Run chi-squared test
chi_test <- chisq.test(counts)

# View results
print(chi_test)


# Calculate Cramer's V
n <- sum(counts)

cramers_v <- sqrt(
  as.numeric(chi_test$statistic) / n
)

print(cramers_v)


# Number of expected counts below 5
sum(chi_test$expected < 5)

# Smallest expected count
min(chi_test$expected)


#correlation test to see if number of species correlates to percentage unidentified
cor.test(
  top100_genera$total_species_accepted_wcvp,
  top100_genera$percentageUnidentified,
  method = "spearman",
  exact = FALSE
)

#Scatterplot for the correlation


ggplot(top100_genera, aes(
  x = total_species_accepted_wcvp,
  y = percentageUnidentified
)) +
  geom_point(
    colour = "#B49AD6",
    size = 3,
    alpha = 0.7
  ) +
  geom_smooth(
    method = "lm",
    se = TRUE,
    colour = "#EFA6C8"
  ) +
  labs(
    title = "Species Richness and Unidentified Specimens",
    subtitle = "Spearman's rho = -0.140, p = 0.164",
    x = "Number of Accepted Species",
    y = "Unidentified Specimens (%)"
  ) +
  theme_minimal()

#Correlation between number of specimens and percentage unidentified


# Calculate total specimens per genus
top100_genera$total_specimens <-
  top100_genera$total_specimens_identificados +
  top100_genera$total_specimens_nao_identificados

# Test relationship with percentage unidentified
cor.test(
  top100_genera$total_specimens,
  top100_genera$percentageUnidentified,
  method = "spearman",
  exact = FALSE
)


#Scatter plot for relationship between specimens and unidentified

ggplot(top100_genera, aes(
  x = total_specimens,
  y = percentageUnidentified
)) +
  geom_point(
    colour = "#B49AD6",
    size = 3,
    alpha = 0.7
  ) +
  geom_smooth(
    method = "lm",
    se = TRUE,
    colour = "#EFA6C8"
  ) +
  scale_x_log10(
    labels = scales::label_comma()
  ) +
  labs(
    title = "Specimen Abundance and Identification",
    subtitle = "Spearman's rho = -0.600, p < 0.001",
    x = "Total Number of Specimens (log scale)",
    y = "Unidentified Specimens (%)"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(
      size = 16, face = "bold"
    ),
    axis.title = element_text(size = 12)
  )


#Correlation between number of species and number of specimens  
cor.test(
  top100_genera$total_species_accepted_wcvp,
  top100_genera$total_specimens,
  method = "spearman",
  exact = FALSE
)

#Correlation between specimens and unidentified accounting for species richness

# Install if needed
install.packages("ppcor")

library(ppcor)

# Partial Spearman correlation
pcor.test(
  x = top100_genera$total_specimens,
  y = top100_genera$percentageUnidentified,
  z = top100_genera$total_species_accepted_wcvp,
  method = "spearman"
)



pcor.test(
  x = top100_genera$total_species_accepted_wcvp,
  y = top100_genera$percentageUnidentified,
  z = top100_genera$total_specimens,
  method = "spearman"
)



