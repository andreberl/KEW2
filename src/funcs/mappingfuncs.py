""" Functions for preparing geospacial data """

import polars as pl
import folium
from folium.plugins import HeatMap
from pathlib import Path

def pull_geo_data_df(data, primary_key, lat_name, long_name): #might delete later
    """
    Generate a df that contains a list of lat and long
    removing those without data.
    """
    df = (
        pl.scan_csv(
            data
            )
            .select([primary_key, lat_name, long_name])
            .drop_nulls(subset=[lat_name,long_name])
            .collect()
    )
    return df

def aggreate_geo_df( #might delete later
        data_ident: str | Path,
        data_unident: str | Path,
        primary_key: str,
        lat_name: str,
        long_name: str,
        ):
    """Generate single df that contains unident and ident lat and long"""
    # Use pull_geo_data_df to pull long/lat data, then append an identified flag
    df_ident = pull_geo_data_df(data_ident, primary_key, lat_name, long_name)
    df_ident = df_ident.with_columns(
        pl.lit("true").alias("identified")
    )
    df_unident = pull_geo_data_df(data_unident, primary_key, lat_name, long_name)
    df_unident = df_unident.with_columns(
            pl.lit("false").alias("identified")
        )
    # append both tables into one df
    df_cord = pl.concat([df_ident, df_unident])
    return df_cord

def load_dataframe(
        data: str | Path,
        lat_name: str,
        long_name: str,
):
    """ Return a df of lat/long for a csv"""
    df = (
    pl.scan_csv(
        data
        )
        .select([lat_name, long_name])
        .drop_nulls()
        .collect()
    )
    return df

def aggregate_coordinates(
        data: str | Path,
        lat_name: str,
        long_name: str,
        resolution: float = 2.0
) -> pl.DataFrame:
    """ Aggregate geographical points """
    df = load_dataframe(data,lat_name,long_name)
    df_agg = (
        df.select(
            pl.col(lat_name).cast(pl.Float64, strict=False).alias("lat"),
            pl.col(long_name).cast(pl.Float64, strict=False).alias("lon")
        )
        .drop_nulls()
        .filter(
            pl.col("lat").is_finite()
            & pl.col("lon").is_finite()
            & pl.col("lat").is_between(-90, 90)
            & pl.col("lon").is_between(-180, 180)
        )
        .with_columns(
            ((pl.col("lat") / resolution).floor() * resolution)
                .clip(-90, 90 - resolution)
                .alias("lat_grid"),
            ((pl.col("lon") / resolution).floor() * resolution)
                .clip(-180, 180 - resolution)
                .alias("lon_grid")
        )
        .group_by(["lat_grid", "lon_grid"])
        .agg(
            pl.len().alias("count")
        )
        .with_columns(
            (pl.col("lat_grid") + resolution / 2).alias("latitude"),
            (pl.col("lon_grid") + resolution / 2).alias("longitude")
        )
        .select(["latitude", "longitude", "count"])
    )

    # Normalize the weights:
    df_agg = df_agg.with_columns(
        (pl.col("count").log1p()/
         pl.col("count").max().log1p()
         ).alias("weight")
    )
    return df_agg

def plot_heatmap(
        df: pl.DataFrame,
        output_path: str | Path
) -> None:
    """HeatMap of geographical data"""
    # Convert the df to a matrix
    coordinates = df.select(
        ["latitude", "longitude", "weight"]
        ).rows()

    # Create the map
    map = folium.Map(
        location=[15, 0],
        zoom_start=2,
        tiles=None,
        control_scale = True
        )

    # Change map colours:
    folium.Rectangle(
        bounds=[[-90,-180],[90, 180]],
        color = "#F8F3F8",
        fill = True,
        fill_color="#F8F3F8",
        fill_opacity=0.001,
        weight=0
    ).add_to(map)

     # Add the heatmap
    HeatMap(
        coordinates,
        radius=22,
        blur=15,
        min_opacity=0.1,
        max_zoom=10,
        gradient={
            0.2: "#F5C542",
            0.4: "#F28C28",
            0.6: "#E04F2D",
            0.8: "#A61C3C",
            1.0: "#570A32"
        }
    ).add_to(map)

    # Add world boundaries
    folium.GeoJson(
        "../res/worldmap.json",
        name="World Map",
        style_function=lambda feature: {
            "color": "#795E4A",
            "weight": 0.7,
            "fillColor": "#EEE5D5",
            "fillOpacity": 0.02
        }
    ).add_to(map)

    # Output the map
    map.save(str(output_path))

    print(f"Heatmap was saved to {output_path}")
    return