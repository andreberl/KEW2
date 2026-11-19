""" Compare the indents to total identified for top 100 sorted by collection year """

from pathlib import Path
from funcs.datamanfuncs import load_data_path, extract_column_count, unidentified_percentage
from funcs.visualization import plot_unident_percentage

# Load the indentified data and unidentified datasets and define output paths
indent_data = load_data_path("top100_registros_identificados_campos_analise.csv")
unindent_data = load_data_path("top100_registros_nao_identificados_campos_analise.csv")


# Analyze by Year #
# Generate dfs containing year count for identified and non-identified
df_year_ident = extract_column_count(indent_data, "Ctrl_year")
df_year_unident = extract_column_count(unindent_data, "Ctrl_year")
# Calculate unidentified percentage and identify output path:
unident_perc_path = Path("outputs") / "unident_perc_year.csv"
unident_perc_df, column_percent = unidentified_percentage(df_year_ident, df_year_unident, "Ctrl_year", "Total_Registrations", unident_perc_path)
# Plot Unidentified Percentages:
plot_output_path = Path("outputs") / "Unidentified_Percentage_Plot.png"
plot_unident_percentage(unident_perc_df, "Ctrl_year", column_percent, plot_output_path)
