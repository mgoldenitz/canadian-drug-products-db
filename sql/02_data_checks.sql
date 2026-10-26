-- Join coverage and the size of the analysis set.
SELECT
    COUNT(*) AS human_products,
    SUM(company_name IS NULL) AS no_company,
    SUM(atc_code IS NULL) AS no_atc,
    SUM(is_homeopathic) AS homeopathic,
    SUM(atc_code IS NOT NULL AND is_homeopathic = 0) AS analysis_set,
    SUM(first_date IS NULL) AS no_status_date,
    SUM(number_of_ais > 1) AS multi_ingredient,
    (SELECT COUNT(*) FROM (SELECT drug_code FROM drug GROUP BY drug_code HAVING COUNT(DISTINCT extract) > 1)) AS codes_in_two_extracts,
    MIN(first_year) AS earliest_year,
    MAX(first_year) AS latest_year
FROM v_human;
