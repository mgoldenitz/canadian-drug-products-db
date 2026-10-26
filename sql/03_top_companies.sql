-- Companies with the most human drug products (DINs) ever listed in the DPD,
-- with how many are marketed today.
SELECT
    company_group,
    COUNT(*) AS products,
    SUM(extract = 'marketed') AS marketed_now,
    COUNT(DISTINCT atc1) AS atc_groups,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_all
FROM v_analysis
GROUP BY company_group
ORDER BY products DESC
LIMIT 25;
