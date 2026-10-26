-- First Canadian product for each psychiatric substance (ATC level 5 code, so
-- salt forms of one drug count together): the year it first appears, the
-- company on that product's record today, and how many products and companies
-- have sold the substance since.
WITH psych AS (
    SELECT drug_code, first_date, company_group, atc3, atc_code, atc_name
    FROM v_analysis
    WHERE is_psych = 1 AND length(atc_code) = 7 AND first_date IS NOT NULL
),
ordered AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY atc_code ORDER BY first_date, drug_code) AS entry_order,
        COUNT(*) OVER (PARTITION BY atc_code) AS products_since
    FROM psych
)
SELECT
    o.atc_code,
    o.atc_name AS substance,
    COALESCE(p.name, o.atc3) AS psych_class,
    substr(o.first_date, 1, 4) AS first_year,
    o.company_group AS first_product_company_now,
    o.products_since,
    (SELECT COUNT(DISTINCT s.company_group) FROM psych s WHERE s.atc_code = o.atc_code) AS companies_since
FROM ordered o
LEFT JOIN psych_class p ON p.atc_level3 = o.atc3
WHERE o.entry_order = 1
ORDER BY first_year, substance;
