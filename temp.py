import csv
from itertools import islice
from pathlib import Path

# This file is in the project root.
INPUT_CSV = Path("local_files/ILESLA_KEW2/unusable_2025_unidentified.csv")
OUTPUT_CSV = Path("local_files/ILESLA_KEW2/database_sample.csv")
ROW_LIMIT = 10_000

OUTPUT_CSV.parent.mkdir(parents=True, exist_ok=True)

with INPUT_CSV.open("r", encoding="utf-8-sig", newline="") as source:
    reader = csv.reader(source)
    header = next(reader)

    with OUTPUT_CSV.open("w", encoding="utf-8", newline="") as sample:
        writer = csv.writer(sample)
        writer.writerow(header)
        writer.writerows(islice(reader, ROW_LIMIT))

print(f"Saved up to {ROW_LIMIT:,} rows to {OUTPUT_CSV}")