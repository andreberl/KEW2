""" Generate graphs for visualizing geospacial data """

from funcs.datamanfuncs import load_data_path
from funcs.mappingfuncs import aggregate_coordinates


df = load_data_path("top100_registros_identificados_campos_analise.csv")
aggregate_coordinates(df, "parseGBIF_decimalLatitude", "parseGBIF_decimalLongitude")