""" Generate graphs for visualizing geospacial data """

from pathlib import Path
from funcs.datamanfuncs import load_data_path
from funcs.mappingfuncs import aggregate_coordinates, plot_heatmap

output_path = Path("outputs") / "aggregate_heatmap.html"

df = load_data_path("top100_registros_identificados_campos_analise.csv")
df_agg = aggregate_coordinates(df, "parseGBIF_decimalLatitude", "parseGBIF_decimalLongitude")
plot_heatmap(df_agg, output_path)