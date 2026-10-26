-- Views used by every query. One row per DPD product (drug_code).
-- first_date is the earliest date in the product's status history. Products from
-- the late 1990s on start with an APPROVED date. Older products start with a
-- MARKETED date recorded as 31 December of the year, so only the year is reliable.

DROP VIEW IF EXISTS v_product;
CREATE VIEW v_product AS
WITH first_status AS (
    SELECT drug_code, MIN(history_date) AS first_date
    FROM status
    GROUP BY drug_code
),
current_status AS (
    SELECT drug_code, MAX(status) AS current_status
    FROM status
    WHERE current_status_flag = 'Y'
    GROUP BY drug_code
),
atc AS (
    SELECT drug_code, MIN(tc_atc_number) AS atc_code, MIN(tc_atc) AS atc_name
    FROM therapeutic_class
    WHERE tc_atc_number IS NOT NULL
    GROUP BY drug_code
),
sched AS (
    SELECT drug_code,
        MAX(schedule = 'HOMEOPATHIC') AS is_homeopathic,
        MAX(schedule NOT IN ('NON-PRESCRIPTION DRUGS', 'HOMEOPATHIC', 'ETHICAL')) AS is_rx
    FROM schedule
    GROUP BY drug_code
),
maker AS (
    SELECT drug_code, MIN(company_name) AS company_name
    FROM company
    GROUP BY drug_code
)
SELECT
    d.drug_code,
    d.din,
    d.brand_name,
    d.class,
    d.extract,
    CAST(d.number_of_ais AS INTEGER) AS number_of_ais,
    m.company_name,
    COALESCE(cc.company_group, m.company_name) AS company_group,
    fs.first_date,
    CAST(substr(fs.first_date, 1, 4) AS INTEGER) AS first_year,
    (CAST(substr(fs.first_date, 1, 4) AS INTEGER) / 5) * 5 AS period_start,
    cs.current_status,
    atc.atc_code,
    atc.atc_name,
    substr(atc.atc_code, 1, 1) AS atc1,
    substr(atc.atc_code, 1, 4) AS atc3,
    substr(atc.atc_code, 1, 3) IN ('N05', 'N06') AS is_psych,
    COALESCE(sc.is_homeopathic, 0) AS is_homeopathic,
    COALESCE(sc.is_rx, 0) AS is_rx
FROM drug d
LEFT JOIN maker m ON m.drug_code = d.drug_code
LEFT JOIN company_clean cc ON cc.company_name = m.company_name
LEFT JOIN first_status fs ON fs.drug_code = d.drug_code
LEFT JOIN current_status cs ON cs.drug_code = d.drug_code
LEFT JOIN atc ON atc.drug_code = d.drug_code
LEFT JOIN sched sc ON sc.drug_code = d.drug_code;

-- Human prescription and non-prescription drugs only (drops veterinary,
-- radiopharmaceutical and disinfectant classes)
DROP VIEW IF EXISTS v_human;
CREATE VIEW v_human AS
SELECT * FROM v_product WHERE class = 'Human';

-- Analysis set: human drugs with an ATC code, excluding homeopathic products
-- (most of which moved to the Natural and Non-prescription Health Products
-- framework after 2004 and have no ATC code)
DROP VIEW IF EXISTS v_analysis;
CREATE VIEW v_analysis AS
SELECT * FROM v_human WHERE atc_code IS NOT NULL AND is_homeopathic = 0;

-- One row per drug line: a company's products with the same ATC code, so the
-- 25, 50 and 100 mg DINs of one company's sertraline count once. first_date is
-- the line's earliest product; is_rx is set if any product in the line is
-- prescription.
DROP VIEW IF EXISTS v_line;
CREATE VIEW v_line AS
SELECT
    company_group,
    atc_code,
    MIN(atc_name) AS atc_name,
    atc1,
    atc3,
    is_psych,
    MAX(is_rx) AS is_rx,
    COUNT(*) AS dins,
    MAX(extract = 'marketed') AS marketed_now,
    MIN(first_date) AS first_date,
    CAST(substr(MIN(first_date), 1, 4) AS INTEGER) AS first_year,
    (CAST(substr(MIN(first_date), 1, 4) AS INTEGER) / 5) * 5 AS period_start
FROM v_analysis
GROUP BY company_group, atc_code;
