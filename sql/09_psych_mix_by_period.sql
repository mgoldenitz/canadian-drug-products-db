-- Mix of psychiatric classes (ATC level 3) within each period's new
-- psychiatric products (DINs) and new psychiatric drug lines.
WITH dins AS (
    SELECT period_start, atc3, COUNT(*) AS products
    FROM v_analysis
    WHERE is_psych = 1 AND period_start IS NOT NULL
    GROUP BY period_start, atc3
),
lines AS (
    SELECT period_start, atc3, COUNT(*) AS lines
    FROM v_line
    WHERE is_psych = 1 AND period_start IS NOT NULL
    GROUP BY period_start, atc3
)
SELECT
    l.period_start,
    l.atc3,
    COALESCE(p.name, 'Other N05/N06') AS psych_class,
    COALESCE(d.products, 0) AS products,
    ROUND(100.0 * COALESCE(d.products, 0) / SUM(COALESCE(d.products, 0)) OVER (PARTITION BY l.period_start), 1) AS pct_of_psych_dins,
    l.lines,
    ROUND(100.0 * l.lines / SUM(l.lines) OVER (PARTITION BY l.period_start), 1) AS pct_of_psych_lines
FROM lines l
LEFT JOIN dins d ON d.period_start = l.period_start AND d.atc3 = l.atc3
LEFT JOIN psych_class p ON p.atc_level3 = l.atc3
ORDER BY l.period_start, l.lines DESC;
