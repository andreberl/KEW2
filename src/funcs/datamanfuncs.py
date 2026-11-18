"""Data Manipulation Functions."""

import csv
import sys
import polars as pl
from collections import Counter
from pathlib import Path


def load_data_path(filename: str):
    """
    Return string of datapath for given filename in 'data' 
    folder one step above project dir
    """
    project_root = Path(__file__).resolve().parents[3]
    return project_root / "data" / filename

def count_unique_genera(data_path: str | Path):
    """
    Return a table that lists the unique Family - Genera combination and the total 
    occurances in the table.
    """
    csv.field_size_limit(sys.maxsize)

    counts = Counter()
    with Path(data_path).open("r", encoding="utf-8-sig", newline="") as file:
        reader = csv.DictReader(file)

        for row in reader:
            family = (row.get("Ctrl_family")).strip()
            genus = (row.get("genus")).strip()

            if family and genus:
                counts[(family, genus)] += 1

    return[
        {"Family": family, "Genus": genus, "Count": count}
        for (family, genus), count in sorted (counts.items())
    ]

def save_genus_counts(data: str | Path, ouput_path: str):
    """Create a csv file for the genus counts."""
    with open(ouput_path, "w", newline="", encoding="utf-8") as file:
        writer = csv.writer(file)
        writer.writerow(["Family", "Genus", "Count"])

        for row in data:
            writer.writerow([row["Family"], row["Genus"], row["Count"]])
    
    return

def extract_column_count(data: str | Path, column_name: str):
    """
    Create df for total number of "Total_Registrations" given by column_name
    """
    df = (
        pl.scan_csv(
            data, 
            schema_overrides={column_name: pl.String},
            )
        .select(column_name)
        .group_by(column_name)
        .len(name="Total_Registrations")
        .sort(column_name)
        .collect()
    )
    return df

def unidentified_percentage(
        data_ident: pl.DataFrame, 
        data_unident: pl.DataFrame, 
        on_column: str, 
        data_column: str, 
        output_path: str | Path
        ):
    """ 
    Compare two values of dataframe for percentage. 
    data_indent and data_unident should be polars dataframes
    on_column and data_column should be string values of columns in the given dataframe where
    data_column is named the same in both columns
    """
    # Join columns and calculate the percentage
    right_column = f"{data_column}_right"
    df = (data_ident.join(
        data_unident,
        on = on_column,
        how = "full",
        coalesce = True
        )
    .with_columns(
            pl.col(data_column).fill_null(0),
            pl.col(right_column).fill_null(0)
        )
    .with_columns(
        pl.when(
            (pl.col(data_column) + pl.col(right_column)) > 0
        )
        .then(
            pl.col(right_column) / 
            (pl.col(data_column) + pl.col(right_column)) * 100
        )
        .otherwise(None)
        .alias("Unidentified_Percentage")
        )
    .sort(on_column)
    )
    # Rename columns to specify orgin
    df = df.rename({
        data_column : "Registrations_Ident",
        right_column : "Registrations_Unident"
    })
    df.write_csv(output_path)
    print(f"Unidentified Percentage calculated for {on_column} and saved under {output_path}")
    return