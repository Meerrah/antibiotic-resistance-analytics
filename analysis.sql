-- ====================================================================
-- PROJECT: Comparative Clinical Assay Analysis (Antibiotic Resistance)
-- AUTHOR: Onuorah Ifechukwu Miracle
-- PURPOSE: SQL scripts to evaluate phytochemical vs. antibiotic efficacy
-- ====================================================================

-- --------------------------------------------------------------------
-- QUERY 1: Compound Performance & MIC Benchmarking
-- Evaluates median-like average MIC and standard deviation by compound class.
-- --------------------------------------------------------------------
SELECT 
    c.compound_class,
    c.compound_name,
    COUNT(f.test_id) AS total_trials,
    ROUND(AVG(f.mic_value_ug_ml), 2) AS avg_mic_ug_ml,
    ROUND(MIN(f.mic_value_ug_ml), 2) AS min_mic_effective,
    ROUND(AVG(f.growth_inhibition_pct), 2) AS avg_inhibition_rate,
    CASE 
        WHEN AVG(f.mic_value_ug_ml) <= 8.0 THEN 'High Potency'
        WHEN AVG(f.mic_value_ug_ml) <= 32.0 THEN 'Moderate Potency'
        ELSE 'Resistant / Low Potency'
    END AS clinical_efficacy_tier
FROM Fact_MIC_Assays f
JOIN Dim_Compounds c ON f.compound_id = c.compound_id
GROUP BY c.compound_class, c.compound_name
ORDER BY avg_mic_ug_ml ASC;


-- --------------------------------------------------------------------
-- QUERY 2: Efficacy by Gram-Stain Classification
-- Demonstrates CTEs and conditional aggregations across pathogen types.
-- --------------------------------------------------------------------
WITH StrainAssayAggregates AS (
    SELECT 
        s.gram_type,
        c.compound_class,
        f.mic_value_ug_ml,
        f.growth_inhibition_pct
    FROM Fact_MIC_Assays f
    JOIN Dim_Bacterial_Strains s ON f.strain_id = s.strain_id
    JOIN Dim_Compounds c ON f.compound_id = c.compound_id
)
SELECT 
    gram_type,
    compound_class,
    COUNT(*) AS total_screenings,
    ROUND(AVG(mic_value_ug_ml), 2) AS avg_mic,
    ROUND(AVG(growth_inhibition_pct), 2) AS avg_inhibition_pct
FROM StrainAssayAggregates
GROUP BY gram_type, compound_class
ORDER BY gram_type, avg_mic ASC;


-- --------------------------------------------------------------------
-- QUERY 3: Multi-Drug Resistance & Potency Ranking (Window Functions)
-- Uses DENSE_RANK() to identify the top-performing alternative for each strain.
-- --------------------------------------------------------------------
WITH RankedEfficacy AS (
    SELECT 
        s.strain_name,
        s.gram_type,
        c.compound_name,
        c.compound_class,
        f.mic_value_ug_ml,
        DENSE_RANK() OVER (
            PARTITION BY s.strain_name 
            ORDER BY f.mic_value_ug_ml ASC
        ) as efficacy_rank
    FROM Fact_MIC_Assays f
    JOIN Dim_Bacterial_Strains s ON f.strain_id = s.strain_id
    JOIN Dim_Compounds c ON f.compound_id = c.compound_id
)
SELECT 
    strain_name,
    gram_type,
    compound_name AS most_effective_agent,
    compound_class,
    mic_value_ug_ml AS lowest_mic_recorded
FROM RankedEfficacy
WHERE efficacy_rank = 1
ORDER BY strain_name;