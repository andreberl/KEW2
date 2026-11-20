""" Functions for preparing geospacial data """

import polars as pl
import folium
import branca.colormap as cm
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
        key: str,
        lat_name: str,
        long_name: str,
):
    """ Return a df of lat/long & key for a csv"""
    df = (
    pl.scan_csv(
        data
        )
        .select([key, lat_name, long_name])
        .drop_nulls()
        .collect()
    )
    return df, lat_name, long_name

def aggregate_coordinates(
        df: pl.DataFrame,
        lat_name: str,
        long_name: str,
        resolution: float = 2.0
) -> pl.DataFrame:
    """ Aggregate geographical points """
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
            0.2: "#2D6A4F",
            0.4: "#8FAE43",
            0.6: "#F4BA32",
            0.8: "#EA6728",
            1.0: "#A51D28"
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

def unident_percentage_geo(
        df_ident: pl.DataFrame,
        df_unident: pl.DataFrame,
) -> pl.DataFrame:
    """Calculate the unidentified percentage for each aggregate cell"""

    df = (
        df_ident.rename({"count": "Identified"})
        .join(
            df_unident.rename({"count": "Unidentified"}),
            on=["latitude", "longitude"],
            how = "full",
            coalesce = True
        )
        .with_columns(
            pl.col("Identified").fill_null(0),
            pl.col("Unidentified").fill_null(0)
        )
        .with_columns((
            (pl.col("Identified") + pl.col("Unidentified"))
        ).alias("Total"))
        .with_columns((
            pl.col("Unidentified") / pl.col("Total") * 100
        ).alias("Unidentified_Percentage"))
    )
    return df
