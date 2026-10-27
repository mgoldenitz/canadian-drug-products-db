-- Every human product containing ketamine (ATC N01AX03, an anaesthetic) or
-- esketamine (N06AX27, an antidepressant), from the drug lookup view.
SELECT
    din,
    brand_name,
    active_ingredients,
    ingredient_strengths,
    atc_code,
    atc_name,
    routes,
    company_group,
    extract,
    current_status,
    first_date
FROM v_drug_lookup
WHERE class = 'Human'
  AND UPPER(active_ingredients) LIKE '%KETAMINE%'
ORDER BY first_date, din;
