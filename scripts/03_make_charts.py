"""Draw the README charts from the CSVs in results/. Needs matplotlib.

Usage:
    python scripts/03_make_charts.py
"""

import csv
from collections import defaultdict
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

root = Path(__file__).resolve().parent.parent
res = root / "results"
img = root / "images"
img.mkdir(exist_ok=True)

SERIES = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300", "#6250d6", "#e34948"]
INK, MUTED, GRID, SURFACE = "#0b0b0b", "#52514e", "#e4e3df", "#fcfcfb"
plt.rcParams.update({
    "font.size": 10, "axes.edgecolor": GRID, "axes.labelcolor": MUTED,
    "xtick.color": MUTED, "ytick.color": MUTED, "text.color": INK,
    "axes.spines.top": False, "axes.spines.right": False,
    "figure.facecolor": SURFACE, "axes.facecolor": SURFACE,
})


def read(name):
    with open(res / f"{name}.csv", newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def save(fig, name):
    fig.tight_layout()
    fig.savefig(img / name, dpi=150)
    plt.close(fig)


def short(name):
    return name.title().replace(" Of ", " of ").replace(" And ", " and ")


# 1. Top 10 companies by prescription drug lines
rows = read("03b_top_companies_rx")[:10][::-1]
fig, ax = plt.subplots(figsize=(7, 4))
ax.barh([short(r["company_group"]) for r in rows], [int(r["rx_drug_lines"]) for r in rows],
        color=SERIES[0], height=0.6)
for i, r in enumerate(rows):
    ax.text(int(r["rx_drug_lines"]) + 5, i, f'{int(r["rx_drug_lines"])}  ({int(r["rx_dins"]):,} DINs)',
            va="center", color=MUTED, fontsize=9)
ax.set_xlim(0, max(int(r["rx_drug_lines"]) for r in rows) * 1.3)
ax.set_xlabel("Prescription drug lines (one per company and drug), all years")
fig.suptitle("Companies with the most prescription drugs in the DPD", x=0.01, ha="left", fontsize=11)
ax.grid(axis="x", color=GRID, linewidth=0.8)
ax.set_axisbelow(True)
save(fig, "top_companies_rx.png")

# 2. Prescription products by ATC main group
rows = sorted(read("04_therapeutic_areas"), key=lambda r: int(r["rx_products"]))
fig, ax = plt.subplots(figsize=(8, 4.8))
labels = [r["therapeutic_area"].split(",")[0] for r in rows]
ax.barh(labels, [int(r["rx_products"]) for r in rows], color=SERIES[0], height=0.6)
for i, r in enumerate(rows):
    ax.text(int(r["rx_products"]) + 50, i, f'{float(r["pct_of_rx"]):.1f}%', va="center", color=MUTED, fontsize=9)
ax.set_xlabel("Prescription products (DINs), all years")
fig.suptitle("Prescription products by therapeutic area (ATC main group)", x=0.01, ha="left", fontsize=11)
ax.grid(axis="x", color=GRID, linewidth=0.8)
ax.set_axisbelow(True)
save(fig, "therapeutic_areas_rx.png")

# 3. Psychiatric share of new prescription drugs by period, counted two ways
rows = [r for r in read("08_psych_share_by_period") if int(r["period_start"]) >= 1955]
x = [int(r["period_start"]) for r in rows]
fig, ax = plt.subplots(figsize=(7.5, 3.8))
for i, (col, label) in enumerate([("psych_pct_of_rx_dins", "DINs (each strength counted)"),
                                  ("psych_pct_of_rx_lines", "Drug lines (strengths combined)")]):
    y = [float(r[col]) for r in rows]
    ax.plot(x, y, color=SERIES[i], linewidth=2, marker="o", markersize=5, label=label)
    ax.annotate(label.split(" (")[0], (x[-1], y[-1]), xytext=(8, 0), textcoords="offset points",
                va="center", color=INK, fontsize=9)
ax.set_xticks(x)
ax.set_xticklabels([f"{p}-{str(p + 4)[2:]}" if p < 2025 else "2025-26" for p in x], rotation=45, ha="right")
ax.set_ylabel("% of new prescription drugs")
ax.set_ylim(0, 27)
ax.set_xlim(x[0] - 2, x[-1] + 10)
ax.axvspan(x[0] - 2, 1993.5, color=GRID, alpha=0.5, linewidth=0)
ax.text(x[0], 26, "Before 1996: only products still sold in 1996", color=MUTED, fontsize=8.5, va="top")

fig.suptitle("Psychiatric drugs (ATC N05, N06) as a share of new prescription drugs,\ncounted as DINs (each strength) and as drug lines (strengths combined)", x=0.01, ha="left", fontsize=10.5)
ax.grid(axis="y", color=GRID, linewidth=0.8)
ax.set_axisbelow(True)
save(fig, "psych_share_rx.png")

# 4. Psychiatric class mix by period (100% stacked bars)
classes = ["Antipsychotics", "Antidepressants", "Anxiolytics", "Hypnotics and sedatives",
           "Psychostimulants and ADHD drugs", "Anti-dementia drugs"]
mix = defaultdict(dict)
for r in read("09_psych_mix_by_period"):
    if int(r["period_start"]) >= 1970 and r["psych_class"] in classes:
        mix[int(r["period_start"])][r["psych_class"]] = int(r["lines"])
periods = sorted(mix)
fig, ax = plt.subplots(figsize=(8, 4.2))
bottom = [0.0] * len(periods)
for i, c in enumerate(classes):
    vals = [100 * mix[p].get(c, 0) / sum(mix[p].values()) for p in periods]
    ax.bar(range(len(periods)), vals, bottom=bottom, color=SERIES[i], width=0.75,
           edgecolor=SURFACE, linewidth=1.5, label=c)
    bottom = [b + v for b, v in zip(bottom, vals)]
n_pre = sum(p < 1995 for p in periods)
ax.axvspan(-0.5, n_pre - 0.5, color=GRID, alpha=0.5, linewidth=0, zorder=0)
ax.text(-0.4, 104, "Before 1996: only products still sold in 1996", color=MUTED, fontsize=8.5, va="center")
ax.set_xticks(range(len(periods)))
ax.set_xticklabels([f"{p}-{str(p + 4)[2:]}" if p < 2025 else "2025-26" for p in periods], rotation=45, ha="right")
ax.set_ylabel("% of new psychiatric drug lines")
ax.set_ylim(0, 108)
ax.set_yticks(range(0, 101, 20))
fig.suptitle("Mix of new psychiatric drug lines by class", x=0.01, ha="left", fontsize=11)
ax.legend(loc="upper left", bbox_to_anchor=(1.01, 1), frameon=False, fontsize=9)
save(fig, "psych_class_mix.png")

print(f"Wrote charts to {img}")
