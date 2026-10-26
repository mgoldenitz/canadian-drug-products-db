-- What happened to psychiatric products: current status by class.
SELECT
    COALESCE(p.name, v.atc3) AS psych_class,
    v.extract,
    COUNT(*) AS products
FROM v_analysis v
LEFT JOIN psych_class p ON p.atc_level3 = v.atc3
WHERE v.is_psych = 1
GROUP BY psych_class, v.extract
ORDER BY psych_class, products DESC;
