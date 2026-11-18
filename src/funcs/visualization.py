"""Visualize genera counts"""

import csv
from pathlib import Path

import matplotlib.pyplot as plt

# visualization.py is in src/funcs; the CSV is in src/outputs.
csv_path = Path(__file__).resolve().parents[1] / "outputs" / "genus_counts.csv"

with csv_path.open("r", encoding="utf-8", newline="") as file:
    reader = csv.DictReader(file)
    counts = [int(row["Count"]) for row in reader]

counts.sort(reverse=True)

plt.figure(figsize=(12, 6))
plt.scatter(range(1, len(counts) + 1), counts, s=12, alpha=0.7)
plt.yscale("log")  # Makes small and large groups easier to compare
plt.xlabel("Groups, ordered from largest to smallest")
plt.ylabel("Records per group (log scale)")
plt.title("Family–genus group sizes")
plt.tight_layout()
plt.show()