-- Rows per table and extract, to check the load against the DPD website counts.
SELECT 'drug' AS table_name, extract, COUNT(*) AS n_rows FROM drug GROUP BY extract
UNION ALL SELECT 'company', extract, COUNT(*) FROM company GROUP BY extract
UNION ALL SELECT 'ingredient', extract, COUNT(*) FROM ingredient GROUP BY extract
UNION ALL SELECT 'status', extract, COUNT(*) FROM status GROUP BY extract
UNION ALL SELECT 'therapeutic_class', extract, COUNT(*) FROM therapeutic_class GROUP BY extract
ORDER BY table_name, extract;
