"""Create the views in sql/00_views.sql, run every other query in sql/, and save
each result to results/<query name>.csv.

Usage:
    python scripts/02_run_queries.py [--db data/dpd.db]
"""

import argparse
import csv
import sqlite3
from pathlib import Path

root = Path(__file__).resolve().parent.parent
ap = argparse.ArgumentParser()
ap.add_argument("--db", type=Path, default=root / "data" / "dpd.db")
ap.add_argument("--out", type=Path, default=root / "results")
args = ap.parse_args()

con = sqlite3.connect(args.db)
con.executescript((root / "sql" / "00_views.sql").read_text())
args.out.mkdir(exist_ok=True)

for path in sorted((root / "sql").glob("*.sql")):
    if path.name.startswith("00_"):
        continue
    cur = con.execute(path.read_text())
    header = [d[0] for d in cur.description]
    rows = cur.fetchall()
    with open(args.out / f"{path.stem}.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)
    print(f"{path.stem}: {len(rows)} rows")
