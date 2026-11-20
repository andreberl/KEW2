""" Generate graphs for visualizing geospacial data """

from pathlib import Path
from funcs.datamanfuncs import load_data_path
from funcs.mappingfuncs import aggregate_coordinates, plot_heatmap, load_dataframe

output_path_ident = Path("outputs") / "ident_aggregate_heatmap.html"

data_ident = load_data_path("top100_registros_identificados_campos_analise.csv")
df, lat_name, long_name = load_dataframe(
    data_ident,
    "Ctrl_key_family_recordedBy_recordNumber",
    "parseGBIF_decimalLatitude",
    "parseGBIF_decimalLongitude"
    )
df_agg_ident = aggregate_coordinates(df, "parseGBIF_decimalLatitude", "parseGBIF_decimalLongitude", 0.25)
plot_heatmap(df_agg_ident, output_path_ident)

output_path_unident = Path("outputs") / "unident_aggregate_heatmap.html"

data_unident = load_data_path("top100_registros_nao_identificados_campos_analise.csv")
df, lat_name, long_name = load_dataframe(
    data_unident,
    "Ctrl_key_family_recordedBy_recordNumber",
    "parseGBIF_decimalLatitude",
    "parseGBIF_decimalLongitude"
    )
df_agg_unident = aggregate_coordinates(df, lat_name, long_name, 0.25)
plot_heatmap(df_agg_unident, output_path_unident)


