"""Write small fake DPD zips (random values, real file layout) so the loader and
queries can be tested before the real extracts are downloaded. The output is test
data only and is never used for results.

Usage:
    python tests/make_fake_extracts.py OUT_DIR
"""

import csv
import io
import random
import sys
import zipfile
from pathlib import Path

random.seed(42)
out = Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=True)
atcs = ["N06AB06", "N05AH04", "N05BA01", "N06BA04", "C09AA02", "J01CA04", "A10BA02", "L01XC02"]
ings = {"N06AB06": "SERTRALINE", "N05AH04": "QUETIAPINE", "N05BA01": "DIAZEPAM",
        "N06BA04": "METHYLPHENIDATE", "C09AA02": "ENALAPRIL", "J01CA04": "AMOXICILLIN",
        "A10BA02": "METFORMIN", "L01XC02": "RITUXIMAB"}
companies = ["PFIZER CANADA ULC", "Pfizer Canada Inc.", "APOTEX INC", "TEVA CANADA LIMITED", "SANDOZ CANADA INCORPORATED"]
months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
code = 1000

for zip_name, suffix, status in [("allfiles.zip", "", "MARKETED"), ("allfiles_ap.zip", "_ap", "APPROVED"),
                                 ("allfiles_ia.zip", "_ia", "CANCELLED POST MARKET"), ("allfiles_dr.zip", "_dr", "DORMANT")]:
    files = {k: [] for k in ["drug", "comp", "ingred", "status", "ther"]}
    for _ in range(60):
        code += 1
        atc = random.choice(atcs)
        cls = random.choice(["Human"] * 9 + ["Veterinary"])
        year = random.randint(1960, 2025)
        files["drug"].append([code, "", cls, f"{code:08d}", f"BRAND {code}", "", "N", "", "1", "01-JAN-2024", "", "", "", ""])
        files["comp"].append([code, "ABC", "1", random.choice(companies), "DIN OWNER"] + [""] * 13)
        files["ingred"].append([code, "1", ings[atc], "", "10", "MG", "", "", "", "", "", "", "", "", ""])
        files["status"].append([code, "N", "APPROVED", f"{random.randint(1, 28):02d}-{random.choice(months)}-{year}", "", "", ""])
        files["status"].append([code, "Y", status, f"01-JAN-{min(year + 2, 2026)}", "", "", ""])
        files["ther"].append([code, atc, ings[atc], "", "", "", ""])
    with zipfile.ZipFile(out / zip_name, "w") as zf:
        for stem, rows in files.items():
            buf = io.StringIO()
            csv.writer(buf, quoting=csv.QUOTE_ALL).writerows(rows)
            zf.writestr(f"{stem}{suffix}.txt", buf.getvalue())
print(f"Wrote fake extracts to {out}")
