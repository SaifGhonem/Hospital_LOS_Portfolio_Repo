-- ============================================================
-- STEP 3: DIAGNOSTIC QUERIES — 3-Breath Method (WHO / WHERE lenses)
-- Each query: DENSE_RANK by avg stay, variance vs. fixed system average
-- ============================================================

-- LENS 1: HOSPITAL — 16-day spread, primary diagnostic lens
WITH hospital_avg AS (
    SELECT Hospital_code,
           COUNT(DISTINCT patientid) AS Total_patient,
           COUNT(DISTINCT case_id) AS Total_cases,
           AVG(age_midpoint) AS avg_age,
           AVG(stay_midpoint) AS avg_stay,
           AVG(admission_deposit) AS avg_deposit
    FROM Cleaned_data
    GROUP BY Hospital_code
),
overall_avg AS (
    SELECT AVG(stay_midpoint) AS overall_avg_stay FROM Cleaned_data
)
SELECT DENSE_RANK() OVER (ORDER BY h.avg_stay DESC) AS hospital_rank,
       h.Hospital_code, h.Total_patient, h.Total_cases,
       h.avg_age, h.avg_stay, h.avg_deposit,
       o.overall_avg_stay, h.avg_stay - o.overall_avg_stay AS stay_difference
FROM hospital_avg h CROSS JOIN overall_avg o
ORDER BY hospital_rank;


-- LENS 2: WARD TYPE — 13-day spread (excluding Ward U, 9-case outlier)
WITH ward_avg AS (
    SELECT Ward_Type,
           COUNT(DISTINCT patientid) AS Total_patient,
           COUNT(DISTINCT case_id) AS Total_cases,
           AVG(age_midpoint) AS avg_age,
           AVG(stay_midpoint) AS avg_stay,
           AVG(admission_deposit) AS avg_deposit
    FROM Cleaned_data
    GROUP BY Ward_Type
),
overall_avg AS (
    SELECT AVG(stay_midpoint) AS overall_avg_stay FROM Cleaned_data
)
SELECT DENSE_RANK() OVER (ORDER BY w.avg_stay DESC) AS ward_rank,
       Ward_Type, w.Total_patient, w.Total_cases,
       w.avg_age, w.avg_stay, w.avg_deposit,
       o.overall_avg_stay, w.avg_stay - o.overall_avg_stay AS stay_difference
FROM ward_avg w CROSS JOIN overall_avg o
ORDER BY ward_rank;


-- LENS 3: DEPARTMENT — 8-day spread, weakest lens (used as context, not primary driver)
WITH department_avg AS (
    SELECT Department,
           COUNT(DISTINCT patientid) AS Total_patient,
           COUNT(DISTINCT case_id) AS Total_cases,
           AVG(age_midpoint) AS avg_age,
           AVG(stay_midpoint) AS avg_stay,
           AVG(admission_deposit) AS avg_deposit
    FROM Cleaned_data
    GROUP BY Department
),
overall_avg AS (
    SELECT AVG(stay_midpoint) AS overall_avg_stay FROM Cleaned_data
)
SELECT DENSE_RANK() OVER (ORDER BY d.avg_stay DESC) AS department_rank,
       Department, d.Total_patient, d.Total_cases,
       d.avg_age, d.avg_stay, d.avg_deposit,
       o.overall_avg_stay, d.avg_stay - o.overall_avg_stay AS stay_difference
FROM department_avg d CROSS JOIN overall_avg o
ORDER BY department_rank;


-- ROOT CAUSE: HOSPITAL 2 + WARD S — the compounding intersection (+10.27 vs. system avg)
WITH hospital_ward_avg AS (
    SELECT Hospital_code, Ward_Type,
           COUNT(DISTINCT patientid) AS Total_patient,
           COUNT(DISTINCT case_id) AS Total_cases,
           AVG(age_midpoint) AS avg_age,
           AVG(stay_midpoint) AS avg_stay,
           AVG(admission_deposit) AS avg_deposit
    FROM Cleaned_data
    GROUP BY Hospital_code, Ward_Type
),
overall_avg AS (
    SELECT AVG(stay_midpoint) AS overall_avg_stay FROM Cleaned_data
)
SELECT DENSE_RANK() OVER (ORDER BY hw.avg_stay DESC) AS hospital_ward_rank,
       Hospital_code, Ward_Type, hw.Total_patient, hw.Total_cases,
       hw.avg_age, hw.avg_stay, hw.avg_deposit,
       o.overall_avg_stay, hw.avg_stay - o.overall_avg_stay AS stay_difference
FROM hospital_ward_avg hw CROSS JOIN overall_avg o
WHERE Hospital_code = 2
ORDER BY hospital_ward_rank;


-- VALIDATION 1: RULING OUT SEVERITY/CASE-MIX at Hospital 2, Ward S
-- Gap holds across every severity tier (including Minor) -> operational, not clinical
WITH hospital_ward_severity AS (
    SELECT Hospital_code, Ward_Type, Severity_of_Illness,
           COUNT(DISTINCT patientid) AS Total_patient,
           COUNT(DISTINCT case_id) AS Total_cases,
           AVG(age_midpoint) AS avg_age,
           AVG(stay_midpoint) AS avg_stay,
           AVG(admission_deposit) AS avg_deposit
    FROM Cleaned_data
    GROUP BY Hospital_code, Ward_Type, Severity_of_Illness
),
overall_avg AS (
    SELECT AVG(stay_midpoint) AS overall_avg_stay FROM Cleaned_data
)
SELECT DENSE_RANK() OVER (ORDER BY hws.avg_stay DESC) AS rank_,
       Hospital_code, Ward_Type, Severity_of_Illness,
       hws.Total_patient, hws.Total_cases, hws.avg_age, hws.avg_stay,
       hws.avg_deposit, o.overall_avg_stay,
       hws.avg_stay - o.overall_avg_stay AS stay_difference
FROM hospital_ward_severity hws CROSS JOIN overall_avg o
WHERE Hospital_code = 2
ORDER BY rank_;


-- VALIDATION 2: CORRECTING THE ER-CONGESTION ASSUMPTION at Hospital 2, Ward S
-- Trauma/Urgent drive the gap more than Emergency, contradicting the initial stakeholder framing
WITH hospital_ward_admission AS (
    SELECT Hospital_code, Ward_Type, Type_of_Admission,
           COUNT(DISTINCT patientid) AS Total_patient,
           COUNT(DISTINCT case_id) AS Total_cases,
           AVG(age_midpoint) AS avg_age,
           AVG(stay_midpoint) AS avg_stay,
           AVG(admission_deposit) AS avg_deposit
    FROM Cleaned_data
    GROUP BY Hospital_code, Ward_Type, Type_of_Admission
),
overall_avg AS (
    SELECT AVG(stay_midpoint) AS overall_avg_stay FROM Cleaned_data
)
SELECT DENSE_RANK() OVER (ORDER BY hwa.avg_stay DESC) AS rank_,
       Hospital_code, Ward_Type, Type_of_Admission,
       hwa.Total_patient, hwa.Total_cases, hwa.avg_age, hwa.avg_stay,
       hwa.avg_deposit, o.overall_avg_stay,
       hwa.avg_stay - o.overall_avg_stay AS stay_difference
FROM hospital_ward_admission hwa CROSS JOIN overall_avg o
WHERE Hospital_code = 2
ORDER BY rank_;
