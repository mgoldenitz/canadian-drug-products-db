-- Companies with the most prescription drug lines (one per company and ATC
-- code, so strengths of one drug count once), with the DIN count beside it.
-- Prescription means any schedule other than non-prescription, ethical or
-- homeopathic.
SELECT
    company_group,
    COUNT(*) AS rx_drug_lines,
    SUM(dins) AS rx_dins,
    ROUND(1.0 * SUM(dins) / COUNT(*), 1) AS dins_per_line,
    SUM(marketed_now) AS lines_marketed_now,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_rx_lines
FROM v_line
WHERE is_rx = 1
GROUP BY company_group
ORDER BY rx_drug_lines DESC
LIMIT 25;
