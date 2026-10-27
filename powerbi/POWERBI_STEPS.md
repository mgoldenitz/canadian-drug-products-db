# Power BI report: build steps

The report has three pages (companies, therapeutic areas, psychiatric drugs) built from the CSVs in this folder. `scripts/04_export_powerbi.py` writes them from `data/dpd.db`.

## 1. Load the tables

In Power BI Desktop, choose Get data, then Text/CSV, and load each file in this folder: `products.csv`, `drug_lines.csv`, `atc_level1.csv`, `psych_class.csv` and `ketamine_products.csv`.

In Power Query, set these types before you click Close & Apply:

- `din`, `drug_code`, `atc1`, `atc3`, `atc_code`, `period_start` and `line_id`: Text. A DIN has leading zeros that Power BI drops if it reads the column as a number.
- `first_date`: Date.
- `first_year`, `is_psych`, `is_rx`, `dins` and `marketed_now`: Whole number.

Power BI guesses each column's type on load and records it as a Changed Type step. When it asks whether to replace that conversion, choose Replace current; Add new step converts the guessed number back to text and leaves DINs without their leading zeros. You can also delete the Changed Type step under Applied Steps and set every type yourself.

## 2. Add a date table

Choose Modeling, then New table, and paste:

```
Date =
ADDCOLUMNS (
    CALENDAR ( DATE ( 1900, 1, 1 ), DATE ( 2026, 12, 31 ) ),
    "Year", YEAR ( [Date] ),
    "Period", FLOOR ( YEAR ( [Date] ), 5 ) & "-" & RIGHT ( FLOOR ( YEAR ( [Date] ), 5 ) + 4, 2 ),
    "Before 1996", IF ( YEAR ( [Date] ) < 1996, "Before 1996", "1996 on" )
)
```

Select the table, choose Mark as date table, and pick the `Date` column.

## 3. Relationships

In Model view, drag these columns together. All are many-to-one, single direction.

- `products[first_date]` to `Date[Date]`
- `drug_lines[first_date]` to `Date[Date]`
- `products[atc1]` to `atc_level1[atc1]`
- `drug_lines[atc1]` to `atc_level1[atc1]`
- `products[atc3]` to `psych_class[atc3]`
- `drug_lines[atc3]` to `psych_class[atc3]`

## 4. Measures

Create a blank table called `Measures` (Enter data, then load an empty table), then select `Measures` in the Data pane and add each measure with Table tools, then New measure. Paste one measure at a time. A measure can't share a name with a table, so the row count is called `Product Count`, not `Products`. Once the measures exist, right-click the placeholder `Column` in `Measures` and choose Hide in report view (it can't be deleted if `Measures` was made as a calculated table):

```
Product Count = COUNTROWS ( products )

Rx Products = CALCULATE ( [Product Count], products[is_rx] = 1 )

Drug Lines = COUNTROWS ( drug_lines )

Rx Drug Lines = CALCULATE ( [Drug Lines], drug_lines[is_rx] = 1 )

Psych Rx Drug Lines = CALCULATE ( [Rx Drug Lines], drug_lines[is_psych] = 1 )

Psych Share of Rx Lines = DIVIDE ( [Psych Rx Drug Lines], [Rx Drug Lines] )

Class Share of Psych Lines =
DIVIDE (
    CALCULATE ( [Drug Lines], drug_lines[is_psych] = 1 ),
    CALCULATE ( [Drug Lines], drug_lines[is_psych] = 1, REMOVEFILTERS ( psych_class ) )
)

DINs per Line = DIVIDE ( SUM ( drug_lines[dins] ), [Drug Lines] )

Company Rank =
RANKX ( ALL ( drug_lines[company_group] ), [Rx Drug Lines], , DESC, Dense )

Cumulative Rx Drug Lines =
CALCULATE ( [Rx Drug Lines], FILTER ( ALL ( 'Date' ), 'Date'[Date] <= MAX ( 'Date'[Date] ) ) )
```

Format `Psych Share of Rx Lines` and `Class Share of Psych Lines` as percentages with one decimal place.

## 5. Pages

Companies:

- Clustered bar chart: `drug_lines[company_group]` on the Y-axis, `Rx Drug Lines` on the X-axis. In the Filters pane, set a Top N filter on `company_group`: top 10 by `Rx Drug Lines`.
- Add `Rx Products` and `DINs per Line` to the tooltip.
- Slicer: `Date[Period]`.

Therapeutic areas:

- Clustered bar chart: `atc_level1[therapeutic_area]` on the Y-axis, `Rx Products` on the X-axis.
- Matrix (heatmap): `atc_level1[therapeutic_area]` in Rows, `Date[Period]` in Columns, `Rx Drug Lines` in Values. Under Format, Cell elements, turn Background color on (one-colour gradient). Add a visual filter `Date[Year]` is greater than or equal to 1970.

Psychiatric drugs:

- Line chart: `Date[Period]` on the X-axis, `Psych Share of Rx Lines` on the Y-axis.
- 100% stacked column chart: `Date[Period]` on the X-axis, `Class Share of Psych Lines` on the Y-axis, `psych_class[psych_class]` as the legend. Filter the visual to periods from 1970-74.
- Table: `ketamine_products` with `brand_name`, `din`, `atc_name`, `company_group`, `current_status` and `first_date`.
- Text box: "Before 1996, the DPD holds only products still sold in 1996."

## 6. Check the numbers

These values come from the SQL queries, so the report should match them:

- Rx drug lines in total: 9,555 (`Rx Drug Lines` with no filters).
- Apotex: 429 Rx drug lines, rank 1.
- Psych Share of Rx Lines: 14.4% in 2005-09 and 7.3% in 2020-24.
- Antidepressants: 56.1% of psychiatric drug lines in 2000-04.
