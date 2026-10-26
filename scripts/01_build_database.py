"""Build a SQLite database from Health Canada's Drug Product Database (DPD) extracts.

Reads the four extract zips in data/raw/ (marketed, approved, inactive, dormant),
loads each related file into one table per file type, tags every row with the
extract it came from, and adds lookup tables for ATC groups and cleaned company
names.

Uses only the Python standard library, so it runs in WSL without installs.

Usage:
    python scripts/01_build_database.py [--raw data/raw] [--db data/dpd.db]
"""

import argparse
import csv
import io
import re
import sqlite3
import sys
import zipfile
from datetime import datetime
from pathlib import Path

# Extract zips and the suffix their member files carry (drug.txt, drug_ia.txt, ...)
EXTRACTS = {
    "marketed": ("allfiles.zip", ""),
    "approved": ("allfiles_ap.zip", "_ap"),
    "inactive": ("allfiles_ia.zip", "_ia"),
    "dormant": ("allfiles_dr.zip", "_dr"),
}

# Column layouts from the DPD data extract read-me. The files have no header row.
# If a release adds or drops trailing columns, the loader pads or names extras and
# reports it instead of failing.
LAYOUTS = {
    "drug": ("drug", [
        "drug_code", "product_categorization", "class", "din", "brand_name",
        "descriptor", "pediatric_flag", "accession_number", "number_of_ais",
        "last_update_date", "ai_group_no", "class_f", "brand_name_f", "descriptor_f",
    ]),
    "comp": ("company", [
        "drug_code", "mfr_code", "company_code", "company_name", "company_type",
        "address_mailing_flag", "address_billing_flag", "address_notification_flag",
        "address_other", "suite_number", "street_name", "city_name", "province",
        "country", "postal_code", "post_office_box", "province_f", "country_f",
    ]),
    "ingred": ("ingredient", [
        "drug_code", "active_ingredient_code", "ingredient", "ingredient_supplied_ind",
        "strength", "strength_unit", "strength_type", "dosage_value", "base",
        "dosage_unit", "notes", "ingredient_f", "strength_unit_f", "strength_type_f",
        "dosage_unit_f",
    ]),
    "status": ("status", [
        "drug_code", "current_status_flag", "status", "history_date", "status_f",
        "lot_number", "expiration_date",
    ]),
    "ther": ("therapeutic_class", ["drug_code", "tc_atc_number", "tc_atc", "tc_atc_f"]),
    "form": ("dosage_form", [
        "drug_code", "pharm_form_code", "pharmaceutical_form", "pharmaceutical_form_f",
    ]),
    "route": ("route", [
        "drug_code", "route_code", "route_of_administration", "route_of_administration_f",
    ]),
    "schedule": ("schedule", ["drug_code", "schedule", "schedule_f"]),
    "pharm": ("pharm_standard", ["drug_code", "pharmaceutical_std"]),
    "package": ("package", [
        "drug_code", "upc", "package_size_unit", "package_type", "package_size",
        "product_information", "package_size_unit_f", "package_type_f",
    ]),
    "vet": ("vet_species", ["drug_code", "vet_species", "vet_sub_species", "vet_species_f"]),
    "biosimilar": ("biosimilar", ["drug_code", "biosimilar_type", "biosimilar_type_f"]),
    # Only in the inactive zip, without the _ia suffix
    "inactive": ("inactive_product", ["drug_code", "din", "brand_name", "inactive_date"]),
}

DATE_COLUMNS = {"last_update_date", "history_date", "expiration_date", "inactive_date"}

# WHO ATC anatomical main groups (level 1)
ATC_LEVEL1 = {
    "A": "Alimentary tract and metabolism",
    "B": "Blood and blood forming organs",
    "C": "Cardiovascular system",
    "D": "Dermatologicals",
    "G": "Genito-urinary system and sex hormones",
    "H": "Systemic hormonal preparations, excluding sex hormones and insulins",
    "J": "Antiinfectives for systemic use",
    "L": "Antineoplastic and immunomodulating agents",
    "M": "Musculo-skeletal system",
    "N": "Nervous system",
    "P": "Antiparasitic products, insecticides and repellents",
    "R": "Respiratory system",
    "S": "Sensory organs",
    "V": "Various",
}

# Psychiatric drugs for this project: ATC N05 (psycholeptics) and N06 (psychoanaleptics)
PSYCH_LEVEL3 = {
    "N05A": "Antipsychotics",
    "N05B": "Anxiolytics",
    "N05C": "Hypnotics and sedatives",
    "N06A": "Antidepressants",
    "N06B": "Psychostimulants and ADHD drugs",
    "N06C": "Psycholeptic and psychoanaleptic combinations",
    "N06D": "Anti-dementia drugs",
}

# Legal-form words stripped when grouping company names
COMPANY_SUFFIXES = re.compile(
    r"\b(INC|INCORPORATED|ULC|LTD|LTEE|LIMITED|LIMITEE|CORP|CORPORATION|CO|COMPANY|"
    r"LLC|LP|SA|AG|GMBH|PLC|SRL|SPA|BV|NV)\b\.?"
)


def parse_date(value):
    """Return an ISO date string, or None. DPD releases have used both 'DD-MON-YYYY'
    and 'YYYY-MM-DD'."""
    value = (value or "").strip()
    if not value:
        return None
    for fmt in ("%d-%b-%Y", "%Y-%m-%d", "%d-%b-%y", "%Y/%m/%d"):
        try:
            return datetime.strptime(value, fmt).date().isoformat()
        except ValueError:
            continue
    return None


def clean_company(name):
    """Uppercase, drop punctuation and legal-form words, collapse spaces."""
    name = (name or "").upper().replace("&", " AND ")
    name = re.sub(r"[.,'()]", " ", name)
    name = COMPANY_SUFFIXES.sub(" ", name)
    return re.sub(r"\s+", " ", name).strip()


def read_member(zf, member):
    raw = zf.read(member)
    for enc in ("utf-8", "cp1252"):
        try:
            text = raw.decode(enc)
            break
        except UnicodeDecodeError:
            continue
    return csv.reader(io.StringIO(text, newline=""))


def build(raw_dir, db_path):
    if db_path.exists():
        db_path.unlink()
    con = sqlite3.connect(db_path)
    report = []
    created = set()

    for extract, (zip_name, suffix) in EXTRACTS.items():
        zip_path = raw_dir / zip_name
        if not zip_path.exists():
            sys.exit(f"Missing {zip_path}. Download all four DPD extract zips first.")
        with zipfile.ZipFile(zip_path) as zf:
            members = {Path(m).name.lower(): m for m in zf.namelist()}
            for stem, (table, cols) in LAYOUTS.items():
                member = members.get(f"{stem}{suffix}.txt") or members.get(f"{stem}.txt")
                if member is None:
                    report.append(f"{extract:9} {stem}{suffix}.txt not in zip")
                    continue
                rows = list(read_member(zf, member))
                widths = {len(r) for r in rows if r}
                width = max(widths) if widths else len(cols)
                all_cols = cols + [f"extra_{i}" for i in range(len(cols), width)]
                if table not in created:
                    col_sql = ", ".join(f'"{c}" TEXT' for c in all_cols)
                    con.execute(f'CREATE TABLE "{table}" (extract TEXT, {col_sql})')
                    created.add(table)
                else:
                    existing = [r[1] for r in con.execute(f'PRAGMA table_info("{table}")')]
                    for c in all_cols:
                        if c not in existing:
                            con.execute(f'ALTER TABLE "{table}" ADD COLUMN "{c}" TEXT')
                date_idx = [i for i, c in enumerate(all_cols) if c in DATE_COLUMNS]
                out = []
                bad_dates = 0
                for r in rows:
                    if not r:
                        continue
                    r = [v.strip() or None for v in r] + [None] * (len(all_cols) - len(r))
                    for i in date_idx:
                        if r[i] is not None:
                            iso = parse_date(r[i])
                            bad_dates += iso is None
                            r[i] = iso
                    out.append([extract] + r)
                placeholders = ", ".join("?" * (len(all_cols) + 1))
                names = ", ".join(['extract'] + [f'"{c}"' for c in all_cols])
                con.executemany(f'INSERT INTO "{table}" ({names}) VALUES ({placeholders})', out)
                note = f"widths {sorted(widths)} vs {len(cols)} expected" if widths != {len(cols)} else ""
                if bad_dates:
                    note += f" {bad_dates} unparsed dates"
                report.append(f"{extract:9} {table:18} {len(out):>8} rows {note}")

    add_lookups(con)
    add_indexes(con)
    con.commit()
    con.close()
    print("\n".join(report))
    print(f"\nWrote {db_path}")


def add_lookups(con):
    con.execute("CREATE TABLE atc_level1 (code TEXT PRIMARY KEY, name TEXT)")
    con.executemany("INSERT INTO atc_level1 VALUES (?, ?)", ATC_LEVEL1.items())
    con.execute("CREATE TABLE psych_class (atc_level3 TEXT PRIMARY KEY, name TEXT)")
    con.executemany("INSERT INTO psych_class VALUES (?, ?)", PSYCH_LEVEL3.items())

    names = [r[0] for r in con.execute("SELECT DISTINCT company_name FROM company WHERE company_name IS NOT NULL")]
    con.execute("CREATE TABLE company_clean (company_name TEXT PRIMARY KEY, company_group TEXT)")
    con.executemany("INSERT INTO company_clean VALUES (?, ?)", [(n, clean_company(n)) for n in names])


def add_indexes(con):
    for table in ["drug", "company", "ingredient", "status", "therapeutic_class",
                  "dosage_form", "route", "schedule", "pharm_standard", "package", "vet_species",
                  "biosimilar", "inactive_product"]:
        exists = con.execute("SELECT 1 FROM sqlite_master WHERE name = ?", (table,)).fetchone()
        if exists:
            con.execute(f'CREATE INDEX "ix_{table}_drug_code" ON "{table}" (drug_code)')


if __name__ == "__main__":
    root = Path(__file__).resolve().parent.parent
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw", type=Path, default=root / "data" / "raw")
    ap.add_argument("--db", type=Path, default=root / "data" / "dpd.db")
    args = ap.parse_args()
    build(args.raw, args.db)
