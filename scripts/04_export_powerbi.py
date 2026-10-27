"""Export the tables the Power BI report uses to powerbi/*.csv.

Usage:
    python scripts/04_export_powerbi.py [--db data/dpd.db]
"""

import argparse
import csv
import sqlite3
from pathlib import Path

root = Path(__file__).resolve().parent.parent
ap = argparse.ArgumentParser()
ap.add_argument("--db", type=Path, default=root / "data" / "dpd.db")
args = ap.parse_args()

con = sqlite3.connect(args.db)
con.executescript((root / "sql" / "00_views.sql").read_text())
out = root / "powerbi"
out.mkdir(exist_ok=True)

EXPORTS = {
    # One row per product (DIN) in the analysis set
    "products": """
        SELECT drug_code, din, brand_name, company_group, atc_code, atc_name, atc1, atc3,
               is_psych, is_rx, extract, current_status, first_date, first_year, period_start
        FROM v_analysis""",
    # One row per drug line (company + ATC code)
    "drug_lines": """
        SELECT company_group || '|' || atc_code AS line_id, company_group, atc_code, atc_name,
               atc1, atc3, is_psych, is_rx, dins, marketed_now, first_date, first_year, period_start
        FROM v_line""",
    "atc_level1": "SELECT code AS atc1, name AS therapeutic_area FROM atc_level1",
    "psych_class": "SELECT atc_level3 AS atc3, name AS psych_class FROM psych_class",
    "ketamine_products": (root / "sql" / "14_esketamine_ketamine.sql").read_text(),
}

for name, sql in EXPORTS.items():
    cur = con.execute(sql)
    rows = cur.fetchall()
    with open(out / f"{name}.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow([d[0] for d in cur.description])
        w.writerows(rows)
    print(f"{name}: {len(rows)} rows")
