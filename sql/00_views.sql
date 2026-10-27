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

-- Drug lookup: one row per product, keyed on DIN, with its active ingredients,
-- dosage forms, routes and schedules flattened into text. Built to be reused
-- when joining other sources (adverse event reports, prescribing data) to the
-- DPD: join on din where the other source has one, otherwise on the
-- ingredient names or the ATC code. A DIN can appear on more than one record
-- (246 extra records in the October 2026 release), so drug_code is the unique key.
DROP VIEW IF EXISTS v_drug_lookup;
CREATE VIEW v_drug_lookup AS
WITH ingr AS (
    SELECT drug_code,
        GROUP_CONCAT(ingredient, '; ') AS active_ingredients,
        GROUP_CONCAT(ingredient || ' ' || COALESCE(strength, '') || ' ' || COALESCE(strength_unit, ''), '; ') AS ingredient_strengths
    FROM (SELECT * FROM ingredient ORDER BY drug_code, ingredient)
    GROUP BY drug_code
),
forms AS (
    SELECT drug_code, GROUP_CONCAT(pharmaceutical_form, '; ') AS dosage_forms
    FROM dosage_form GROUP BY drug_code
),
routes AS (
    SELECT drug_code, GROUP_CONCAT(route_of_administration, '; ') AS routes
    FROM route GROUP BY drug_code
),
scheds AS (
    SELECT drug_code, GROUP_CONCAT(schedule, '; ') AS schedules
    FROM schedule GROUP BY drug_code
)
SELECT
    p.din,
    p.drug_code,
    p.brand_name,
    p.class,
    i.active_ingredients,
    i.ingredient_strengths,
    p.number_of_ais,
    p.atc_code,
    p.atc_name,
    f.dosage_forms,
    r.routes,
    s.schedules,
    p.is_rx,
    p.company_name,
    p.company_group,
    p.extract,
    p.current_status,
    p.first_date
FROM v_product p
LEFT JOIN ingr i ON i.drug_code = p.drug_code
LEFT JOIN forms f ON f.drug_code = p.drug_code
LEFT JOIN routes r ON r.drug_code = p.drug_code
LEFT JOIN scheds s ON s.drug_code = p.drug_code;
