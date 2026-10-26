-- Top five companies by psychiatric products in each decade.
WITH by_company AS (
    SELECT (first_year / 10) * 10 AS decade, company_group, COUNT(*) AS products
    FROM v_analysis
    WHERE is_psych = 1 AND first_year IS NOT NULL
    GROUP BY decade, company_group
),
ranked AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY decade ORDER BY products DESC, company_group) AS rnk,
        ROUND(100.0 * products / SUM(products) OVER (PARTITION BY decade), 1) AS pct_of_decade
    FROM by_company
)
SELECT decade, rnk, company_group, products, pct_of_decade
FROM ranked
WHERE rnk <= 5
ORDER BY decade, rnk;
