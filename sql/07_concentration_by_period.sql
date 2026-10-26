-- Concentration of new prescription drug lines per period: share held by the
-- top 10 companies, and the Herfindahl-Hirschman index (0 to 10,000).
WITH by_company AS (
    SELECT period_start, company_group, COUNT(*) AS lines
    FROM v_line
    WHERE period_start IS NOT NULL AND is_rx = 1
    GROUP BY period_start, company_group
),
shares AS (
    SELECT
        period_start, company_group, lines,
        100.0 * lines / SUM(lines) OVER (PARTITION BY period_start) AS pct,
        ROW_NUMBER() OVER (PARTITION BY period_start ORDER BY lines DESC) AS rnk
    FROM by_company
)
SELECT
    period_start,
    SUM(lines) AS rx_drug_lines,
    COUNT(*) AS companies,
    ROUND(SUM(CASE WHEN rnk <= 10 THEN pct END), 1) AS top10_pct,
    ROUND(SUM(pct * pct), 0) AS hhi,
    MAX(CASE WHEN rnk = 1 THEN company_group END) AS top_company
FROM shares
GROUP BY period_start
ORDER BY period_start;
