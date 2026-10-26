-- Products by ATC anatomical main group, split into prescription and
-- non-prescription.
SELECT
    v.atc1,
    a.name AS therapeutic_area,
    COUNT(*) AS products,
    SUM(v.is_rx) AS rx_products,
    COUNT(*) - SUM(v.is_rx) AS non_rx_products,
    SUM(v.extract = 'marketed') AS marketed_now,
    COUNT(DISTINCT v.company_group) AS companies,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_all,
    ROUND(100.0 * SUM(v.is_rx) / SUM(SUM(v.is_rx)) OVER (), 1) AS pct_of_rx
FROM v_analysis v
JOIN atc_level1 a ON a.code = v.atc1
GROUP BY v.atc1, a.name
ORDER BY products DESC;
