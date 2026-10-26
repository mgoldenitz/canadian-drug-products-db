-- Products by therapeutic area and five-year period of first status date,
-- with each area's share of that period's products.
WITH counts AS (
    SELECT period_start, atc1, COUNT(*) AS products
    FROM v_analysis
    WHERE period_start IS NOT NULL
    GROUP BY period_start, atc1
)
SELECT
    c.period_start,
    c.atc1,
    a.name AS therapeutic_area,
    c.products,
    ROUND(100.0 * c.products / SUM(c.products) OVER (PARTITION BY c.period_start), 1) AS pct_of_period
FROM counts c
JOIN atc_level1 a ON a.code = c.atc1
ORDER BY c.period_start, c.products DESC;
