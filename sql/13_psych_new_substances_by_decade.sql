-- New psychiatric substances (first product in Canada) per decade and class.
WITH firsts AS (
    SELECT atc_code, atc3, MIN(first_year) AS first_year
    FROM v_analysis
    WHERE is_psych = 1 AND length(atc_code) = 7 AND first_year IS NOT NULL
    GROUP BY atc_code, atc3
)
SELECT
    (f.first_year / 10) * 10 AS decade,
    COALESCE(p.name, f.atc3) AS psych_class,
    COUNT(*) AS new_substances
FROM firsts f
LEFT JOIN psych_class p ON p.atc_level3 = f.atc3
GROUP BY decade, psych_class
ORDER BY decade, new_substances DESC;
