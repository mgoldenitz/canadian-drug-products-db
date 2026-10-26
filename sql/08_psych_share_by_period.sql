-- Psychiatric drugs (ATC N05 + N06) as a share of new prescription products
-- (DINs) and of new prescription drug lines, per five-year period.
WITH dins AS (
    SELECT period_start, SUM(is_rx) AS rx_dins, SUM(is_psych AND is_rx) AS psych_rx_dins
    FROM v_analysis
    WHERE period_start IS NOT NULL
    GROUP BY period_start
),
lines AS (
    SELECT period_start, SUM(is_rx) AS rx_lines, SUM(is_psych AND is_rx) AS psych_rx_lines
    FROM v_line
    WHERE period_start IS NOT NULL
    GROUP BY period_start
)
SELECT
    d.period_start,
    d.rx_dins,
    d.psych_rx_dins,
    ROUND(100.0 * d.psych_rx_dins / NULLIF(d.rx_dins, 0), 1) AS psych_pct_of_rx_dins,
    l.rx_lines,
    l.psych_rx_lines,
    ROUND(100.0 * l.psych_rx_lines / NULLIF(l.rx_lines, 0), 1) AS psych_pct_of_rx_lines
FROM dins d
JOIN lines l ON l.period_start = d.period_start
ORDER BY d.period_start;
