""" Generate graphs for visualizing geospacial data """

from pathlib import Path
from funcs.datamanfuncs import load_data_path
from funcs.mappingfuncs import aggregate_coordinates, plot_heatmap

output_path_ident = Path("outputs") / "ident_aggregate_heatmap.html"

df = load_data_path("top100_registros_identificados_campos_analise.csv")
df_agg = aggregate_coordinates(df, "parseGBIF_decimalLatitude", "parseGBIF_decimalLongitude", 0.25)
plot_heatmap(df_agg, output_path_ident)

output_path_unident = Path("outputs") / "unident_aggregate_heatmap.html"

df = load_data_path("top100_registros_nao_identificados_campos_analise.csv")
df_agg = aggregate_coordinates(df, "parseGBIF_decimalLatitude", "parseGBIF_decimalLongitude", 0.25)
plot_heatmap(df_agg, output_path_unident)