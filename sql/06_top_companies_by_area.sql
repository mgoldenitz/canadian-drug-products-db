-- Top five companies in each therapeutic area, and their share of the area.
WITH by_company AS (
    SELECT atc1, company_group, COUNT(*) AS products
    FROM v_analysis
    
    GROUP BY atc1, company_group
),
ranked AS (
    SELECT
        atc1, company_group, products,
        ROW_NUMBER() OVER (PARTITION BY atc1 ORDER BY products DESC, company_group) AS rank_in_area,
        ROUND(100.0 * products / SUM(products) OVER (PARTITION BY atc1), 1) AS pct_of_area
    FROM by_company
)
SELECT r.atc1, a.name AS therapeutic_area, r.rank_in_area, r.company_group, r.products, r.pct_of_area
FROM ranked r
JOIN atc_level1 a ON a.code = r.atc1
WHERE r.rank_in_area <= 5
ORDER BY r.atc1, r.rank_in_area;
