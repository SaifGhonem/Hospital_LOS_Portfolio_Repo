-- ============================================================
-- STEP 2: DATA CLEANING — Cleaned_data view
-- Fixes bucket-label corruption, converts ranges to midpoints,
-- removes rows with missing Bed Grade / City_Code_Patient
-- ============================================================

CREATE OR ALTER VIEW Cleaned_data AS
SELECT
    case_id,
    Hospital_code,
    Hospital_type_code,
    City_Code_Hospital,
    Hospital_region_code,
    [Available Extra Rooms in Hospital] AS Available_Extra_Rooms_in_Hospital,
    Department,
    Ward_Type,
    Ward_Facility_Code,
    [Bed Grade] AS Bed_Grade,
    patientid,
    City_Code_Patient,
    [Type of Admission] AS Type_of_Admission,
    Severity_of_Illness,
    [Visitors with Patient] AS Visitors_with_Patient,

    CASE WHEN Age = '20-Nov' THEN '11-20' ELSE Age END AS Age,
    CASE
        WHEN Age = '0-10'   THEN 5   WHEN Age = '11-20'  THEN 15
        WHEN Age = '21-30'  THEN 25  WHEN Age = '31-40'  THEN 35
        WHEN Age = '41-50'  THEN 45  WHEN Age = '51-60'  THEN 55
        WHEN Age = '61-70'  THEN 65  WHEN Age = '71-80'  THEN 75
        WHEN Age = '81-90'  THEN 85  WHEN Age = '91-100' THEN 95
        WHEN Age = '20-Nov' THEN 15
    END AS Age_Midpoint,

    Admission_Deposit,

    CASE WHEN Stay = '20-Nov' THEN '11-20' ELSE Stay END AS Stay,
    CASE
        WHEN Stay = '20-Nov'              THEN 15
        WHEN Stay = 'More than 100 Days'  THEN 100   -- capped estimate, true value likely higher
        WHEN Stay = '0-10'                THEN 5
        WHEN Stay = '11-20'               THEN 15
        WHEN Stay = '21-30'               THEN 25
        WHEN Stay = '31-40'               THEN 35
        WHEN Stay = '41-50'               THEN 45
        WHEN Stay = '51-60'               THEN 55
        WHEN Stay = '61-70'               THEN 65
        WHEN Stay = '71-80'               THEN 75
        WHEN Stay = '81-90'               THEN 85
        WHEN Stay = '91-100'              THEN 95
    END AS Stay_Midpoint

FROM train_data
WHERE [Bed Grade] IS NOT NULL
  AND City_Code_Patient IS NOT NULL;


-- ============================================================
-- STEP 4: STAR SCHEMA — Dimension & Fact tables
-- ============================================================

CREATE TABLE Dim_Hospital (
    Hospital_key INT IDENTITY(1,1) PRIMARY KEY,
    Hospital_code INT,
    Hospital_type_code CHAR(1),
    City_Code_Hospital INT,
    Hospital_region_code CHAR(1)
);
INSERT INTO Dim_Hospital (Hospital_code, Hospital_type_code, City_Code_Hospital, Hospital_region_code)
SELECT DISTINCT Hospital_code, Hospital_type_code, City_Code_Hospital, Hospital_region_code
FROM Cleaned_data;

CREATE TABLE Dim_Ward (
    Ward_key INT IDENTITY(1,1) PRIMARY KEY,
    Hospital_code INT,
    Ward_Type CHAR(1),
    Ward_Facility_Code CHAR(1)
);
INSERT INTO Dim_Ward (Hospital_code, Ward_Type, Ward_Facility_Code)
SELECT DISTINCT Hospital_code, Ward_Type, Ward_Facility_Code
FROM Cleaned_data;

CREATE TABLE Dim_Department (
    Department_key INT IDENTITY(1,1) PRIMARY KEY,
    Department VARCHAR(30)
);
INSERT INTO Dim_Department (Department)
SELECT DISTINCT Department FROM Cleaned_data;

CREATE TABLE Dim_Patient (
    Patient_key INT IDENTITY(1,1) PRIMARY KEY,
    patientid INT,
    City_Code_Patient INT,
    Age CHAR(10),
    Age_Midpoint INT
);
INSERT INTO Dim_Patient (patientid, City_Code_Patient, Age, Age_Midpoint)
SELECT DISTINCT patientid, City_Code_Patient, Age, Age_Midpoint
FROM Cleaned_data;

CREATE TABLE Dim_Admission_Type (
    Admission_Type_key INT IDENTITY(1,1) PRIMARY KEY,
    Type_of_Admission VARCHAR(15)
);
INSERT INTO Dim_Admission_Type (Type_of_Admission)
SELECT DISTINCT Type_of_Admission FROM Cleaned_data;

CREATE TABLE Dim_Severity (
    Severity_key INT IDENTITY(1,1) PRIMARY KEY,
    Severity_of_Illness VARCHAR(15)
);
INSERT INTO Dim_Severity (Severity_of_Illness)
SELECT DISTINCT Severity_of_Illness FROM Cleaned_data;

CREATE TABLE Dim_Bed_Grade (
    Bed_Grade_key INT IDENTITY(1,1) PRIMARY KEY,
    Bed_Grade INT
);
INSERT INTO Dim_Bed_Grade (Bed_Grade)
SELECT DISTINCT Bed_Grade FROM Cleaned_data;

CREATE TABLE Fact_Admissions (
    case_id INT PRIMARY KEY,
    Hospital_key INT,
    Ward_key INT,
    Patient_key INT,
    Department_key INT,
    Admission_Type_key INT,
    Severity_key INT,
    Bed_Grade_key INT,
    Available_Extra_Rooms_in_Hospital INT,
    Visitors_with_Patient INT,
    Admission_Deposit DECIMAL(10,2),
    Stay VARCHAR(20),
    Stay_Midpoint INT
);

INSERT INTO Fact_Admissions (
    case_id, Hospital_key, Ward_key, Patient_key, Department_key,
    Admission_Type_key, Severity_key, Bed_Grade_key,
    Available_Extra_Rooms_in_Hospital, Visitors_with_Patient,
    Admission_Deposit, Stay, Stay_Midpoint
)
SELECT
    c.case_id, dh.Hospital_key, dw.Ward_key, dp.Patient_key, dd.Department_key,
    da.Admission_Type_key, ds.Severity_key, db.Bed_Grade_key,
    c.Available_Extra_Rooms_in_Hospital, c.Visitors_with_Patient,
    c.Admission_Deposit, c.Stay, c.Stay_Midpoint
FROM Cleaned_data c
JOIN Dim_Hospital dh ON c.Hospital_code = dh.Hospital_code
JOIN Dim_Ward dw ON c.Ward_Type = dw.Ward_Type AND c.Hospital_code = dw.Hospital_code
JOIN Dim_Patient dp ON c.patientid = dp.patientid
JOIN Dim_Department dd ON c.Department = dd.Department
JOIN Dim_Admission_Type da ON c.Type_of_Admission = da.Type_of_Admission
JOIN Dim_Severity ds ON c.Severity_of_Illness = ds.Severity_of_Illness
JOIN Dim_Bed_Grade db ON c.Bed_Grade = db.Bed_Grade;
