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

def plot_stacked_registers(
        df: pl.DataFrame,
        x_column_name: str,
        y_ident_name: str,
        y_unident_name: str,
        output_path: str | Path,
        x_bound: tuple[int, int] = (1000,3000)
        ) -> None:
    # Filter for just desired bounds:
    df = (
        df.with_columns(
            pl.col(x_column_name)
            .cast(pl.Int64, strict = False)
        )
        .filter(
            pl.col(x_column_name).is_between(
                x_bound[0],
                x_bound[1]
            )
        )
        .sort(x_column_name)
    )
    # pull x and y into lists
    x_list = df[x_column_name].to_list()
    yident_list = df[y_ident_name].to_list()
    yunident_list = df[y_unident_name].to_list()
    # Add colours!
    background = "#F8F3E8"
    text_color = "#534238"
    fig, ax = plt.subplots(figsize=(15,7))
    fig.patch.set_facecolor(background)
    ax.set_facecolor(background)
    #Plot Identified
    ax.bar(
        x_list,
        yident_list,
        width = 8,
        color = "#e76c01",
        label = "Identified"
    )

    #Unident plot
    ax.bar(
        x_list,
        yunident_list,
        bottom = yident_list,
        width = 8,
        color = "#155825",
        label = "Unidentified"
    )

    #Add labels
    ax.set_xlabel("Decade", fontsize=12, color=text_color)
    ax.set_ylabel("Number of Registrations", fontsize=12, color=text_color)

    ax.set_title(
        "Identified vs Unidentified Registrations by Decade",
        fontsize=16,
        fontweight="bold",
        color=text_color,
        pad=20
    )

    # Format x-axis
    ax.set_xticks(x_list)
    ax.tick_params(axis="x", labelsize=9, rotation=45)
    ax.tick_params(axis="y", labelsize=10)

    # Limit visible x-axis to selected bounds
    ax.set_xlim(x_bound[0] - 5, x_bound[1] + 5)

    # Gridlines
    ax.grid(axis="y", linestyle="--", alpha=0.3)
    ax.set_axisbelow(True)

    # Remove borders
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)

    # Legend
    ax.legend(frameon=False, fontsize=11)

    # Save
    plt.tight_layout()

    output_path = Path(output_path)

    plt.savefig(
        output_path,
        dpi=300,
        bbox_inches="tight",
        facecolor=fig.get_facecolor()
    )

    plt.close()
    return