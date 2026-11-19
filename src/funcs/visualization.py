"""Visualize genera counts"""

from pathlib import Path
import polars as pl
import matplotlib.pyplot as plt

def plot_unident_percentage(df: pl.DataFrame, x_column_name: str, y_column_name: str, output_path: str | Path):
    # pull x and y into lists
    x_list = df[x_column_name].to_list()
    y_list = df[y_column_name].to_list()
    # Convert x to labels, if missing, label as 'None'
    labels = ["Missing Label" if x is None else str(x) for x in x_list]
    # Sort Chronologically with missing last
    rows = sorted(
        zip(labels, y_list),
        key=lambda row: (
            row[0] in ("Missing Label", "", None), 
            int(row[0]) if row[0] not in ("Missing Label", "", None) else 0
            )
    )
    labels, y_list = zip(*rows)

    plt.figure(figsize=(14, 6))
    plt.bar(labels, y_list)
    plt.xlabel(x_column_name)
    plt.ylabel(y_column_name)
    plt.title(f"{y_column_name} vs {x_column_name}")
    plt.xticks(fontsize=2, rotation=45)
    plt.tight_layout()
    plt.savefig(output_path, dpi=300, bbox_inches="tight")
    plt.close()
    return