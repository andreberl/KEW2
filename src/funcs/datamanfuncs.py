"""Data Manipulation Functions."""

import csv
import sys
from collections import Counter
from pathlib import Path


def load_data_path():
    """ Return string of datapath """
    project_root = Path(__file__).resolve().parents[2]
    return project_root / "local_files" / "datafile" / "top100_registros_identificados_campos_analise.csv"

def count_unique_genera(data_path):
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

def save_genus_counts(data, ouput_path):
    """Create a csv file for the genus counts."""
    with open(ouput_path, "w", newline="", encoding="utf-8") as file:
        writer = csv.writer(file)
        writer.writerow(["Family", "Genus", "Count"])

        for row in data:
            writer.writerow([row["Family"], row["Genus"], row["Count"]])