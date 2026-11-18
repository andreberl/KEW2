""" Count the number of given genera"""

from funcs.datamanfuncs import count_unique_genera, load_data_path, save_genus_counts
from pathlib import Path

data_path = load_data_path()
genera_count = count_unique_genera(data_path)

output_path = Path("outputs") / "genus_counts.csv"
save_genus_counts(genera_count, output_path)