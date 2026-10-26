-- Checks the product dates for a pile-up: products per first year, how many
-- carry a year-only date (31 December), and the largest number on a single day.
SELECT
    first_year,
    COUNT(*) AS products,
    SUM(is_rx) AS rx_products,
    SUM(substr(first_date, 6, 5) = '12-31') AS dec31_dates,
    MAX(CASE WHEN substr(first_date, 6, 5) <> '12-31' THEN n_same_day END) AS max_on_one_exact_day
FROM (
    SELECT *, COUNT(*) OVER (PARTITION BY first_date) AS n_same_day
    FROM v_analysis
) t
WHERE first_year >= 1950
GROUP BY first_year
ORDER BY first_year;
