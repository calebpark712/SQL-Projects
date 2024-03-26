/*
Patient Medication Data Exploration (Synthea)

Skills Used: joins, CTE's, temp tables, stored procedures, string manipulation, aggregate functions, views
*/

------------------------------------------------------------------------------------------------------------------
---- 1. Data Cleaning

--- Standardize Dates

SELECT birthdateConverted, deathdateConverted
FROM patients;

ALTER TABLE patients
ADD birthdateConverted DATE
ADD deathdateConverted DATE
ADD age INT
DROP COLUMN BIRTHDATE
DROP COLUMN DEATHDATE
DROP COLUMN BIRTHPLACE;

UPDATE patients
SET birthdateConverted = CONVERT(DATE, BIRTHDATE)

UPDATE patients
SET deathdateConverted = CONVERT(DATE, CONVERT(DATE, DEATHDATE, 101), 126)


--- Birthplace into Individual Columns (City, State, Country)
SELECT 
	SUBSTRING(BIRTHPLACE, 1, CHARINDEX('  ', BIRTHPLACE) -1) AS birthCity,
	SUBSTRING(BIRTHPLACE, CHARINDEX('  ', BIRTHPLACE) +1, CHARINDEX('  ', BIRTHPLACE, CHARINDEX('  ', BIRTHPLACE) + 1) - CHARINDEX('  ', BIRTHPLACE) - 1) AS birthState,
    RIGHT(BIRTHPLACE, 2) AS birthCountry
FROM patients;

ALTER TABLE patients
--ADD birthCity nvarchar(255)
--ADD birthState nvarchar(255)
ADD birthCountry nvarchar(255);

UPDATE patients
SET birthCity = SUBSTRING(BIRTHPLACE, 1, CHARINDEX('  ', BIRTHPLACE) -1) 

UPDATE patients
SET birthState = SUBSTRING(BIRTHPLACE, CHARINDEX('  ', BIRTHPLACE) +1, CHARINDEX('  ', BIRTHPLACE, CHARINDEX('  ', BIRTHPLACE) + 1) - CHARINDEX('  ', BIRTHPLACE) - 1) 

UPDATE patients
SET birthCountry = RIGHT(BIRTHPLACE, 2)

--- Create an 'Age' Column based on DOB
SELECT 
    Id,
	birthdateConverted,
	deathdateConverted,
    CASE 
        WHEN deathdateConverted IS NULL THEN DATEDIFF(YEAR, birthdateConverted, GETDATE())
        ELSE DATEDIFF(YEAR, birthdateConverted, deathdateConverted)
    END AS age
FROM 
    patients;

UPDATE patients
SET age =  -- calculated to real-time present date
	(CASE 
        WHEN deathdateConverted IS NULL THEN DATEDIFF(YEAR, birthdateConverted, GETDATE())
        ELSE DATEDIFF(YEAR, birthdateConverted, deathdateConverted)
    END) 

--- Round Healthcare Coverage Costs
SELECT HEALTHCARE_COVERAGE, ROUND(HEALTHCARE_COVERAGE, 2)
FROM patients

UPDATE patients
SET HEALTHCARE_COVERAGE = ROUND(HEALTHCARE_COVERAGE, 2)

SELECT *
FROM patients

------------------------------------------------------------------------------------------------------------------
---- 2. Data Exploration

---- 2A. Patient Data Exploration


-- Which cities do most patients reside?
SELECT city, COUNT(id) AS patients
FROM patients
GROUP BY city
ORDER BY COUNT(id) DESC

-- Which encounter class was highest among all patients?
SELECT e.encounterclass, COUNT(patient) AS count
FROM encounters e
LEFT JOIN patients p
ON e.patient = p.id
GROUP BY e.encounterclass
ORDER BY COUNT(patient) DESC;

-- Which month had the most "wellness" count of cases?
GO
CREATE PROCEDURE 
EncounterClassCase
	@encounterClassType nvarchar(100)
AS
BEGIN
    SET NOCOUNT ON;

SELECT MONTH(e.start) AS month, COUNT(MONTH(e.start)) AS count
FROM encounters e
INNER JOIN patients p
ON e.patient = p.id
WHERE e.encounterclass = @encounterClassType AND YEAR(e.start) >= '2015'
GROUP BY e.encounterclass, MONTH(e.start)
ORDER BY count DESC;
END;

GO
EXEC EncounterClassCase @encounterClassType = 'wellness'

-- What are the top 20 cases of conditions and the average age of patients for each condition?
SELECT TOP 20 c.description, COUNT(description) AS count, AVG(DISTINCT p.age) AS average_age
FROM conditions c
LEFT JOIN patients p
ON c.patient = p.id
GROUP BY description
ORDER BY COUNT(description) DESC



---- 2B. Patient Medication Data Exploration


-- What is the most prescribed drug for different age groups?
WITH AgeGroups AS (
SELECT
    CASE
        WHEN p.age <= 18 THEN '0-18'
        WHEN p.age <= 65 THEN '19-65'
        ELSE '66 and greater'
    END AS age_group,
    description,
    ROW_NUMBER() OVER(PARTITION BY 
	CASE
		WHEN p.age <= 18 THEN '0-18'
        WHEN p.age <= 65 THEN '19-65'
        ELSE '66 and greater'
    END
ORDER BY COUNT(*) DESC) AS rn
FROM
    medications m
INNER JOIN patients p
ON m.patient = p.id
GROUP BY
    CASE
        WHEN p.age <= 18 THEN '0-18'
        WHEN p.age <= 65 THEN '19-65'
        ELSE '66 and greater'
    END,
    description
)

SELECT
    age_group,
    description
FROM
    AgeGroups
WHERE
    rn = 1;

-- Which drug was prescribed the most in every year + month since 2010
WITH monthPrescriptions AS (
SELECT
    description,
    DATEPART(YEAR, start) AS prescription_year,
    DATEPART(MONTH, start) AS prescription_month,
    ROW_NUMBER() OVER (PARTITION BY DATEPART(YEAR, start), DATEPART(MONTH, start) ORDER BY COUNT(*) DESC) AS rn
FROM
    medications
GROUP BY
    description,
    DATEPART(YEAR, start),
    DATEPART(MONTH, start)
)
SELECT prescription_year, prescription_month, description
FROM monthPrescriptions
WHERE rn = 1 AND prescription_year >= '2010'
ORDER BY prescription_year DESC, prescription_month;

-- Find all patients that are taking multiple medications simultaenously
SELECT patient, COUNT(DISTINCT description) AS num_of_prescriptions
FROM medications
GROUP BY patient
HAVING COUNT(DISTINCT description) >= 2


-- What are the top 10 conditions and their codes for medication?
SELECT TOP 10 ReasonDescription, ReasonCode, COUNT(ReasonDescription) AS desc_count
FROM medications
GROUP BY ReasonDescription, ReasonCode
ORDER BY COUNT(ReasonDescription) DESC



---- 2C. Patient Insurance/Cost Data Exploration


-- What are the top 5 drugs in terms of total cost?
SELECT TOP 5 
	description, 
	ROUND(SUM(totalcost), 2) AS total_expenses,
	COUNT(encounter) AS encounters
FROM medications
GROUP BY description
ORDER BY SUM(totalcost) DESC

-- Which patients had the highest total medication expenses for "Simvastatin 10 MG Oral Tablet" and who are their payers (insurance)?
SELECT p.first, p.last, ROUND((p.HEALTHCARE_EXPENSES), 2) AS total_expenses
FROM patients p
WHERE p.id IN (
	SELECT DISTINCT patient
	FROM medications m
	WHERE m.description = 'Simvastatin 10 MG Oral Tablet'
)
ORDER BY HEALTHCARE_EXPENSES DESC

-- Which Insurance Payers covered most encounter costs (in %)?
SELECT 
	pay.name, 
	ROUND(SUM(e.PAYER_COVERAGE), 2) AS encounter_cost_covered, 
	pay.AMOUNT_COVERED AS total_amt_covered, 
	ROUND((ROUND(SUM(e.PAYER_COVERAGE), 2) / pay.AMOUNT_COVERED) * 100, 2) AS encounter_cost_cov_perc
FROM encounters e
LEFT JOIN payers pay
ON e.payer = pay.id
WHERE pay.name != 'NO_INSURANCE'
GROUP BY pay.name, pay.AMOUNT_COVERED
ORDER BY encounter_cost_cov_perc DESC

-- What are the demographic differences across each payer?
DROP TABLE IF EXISTS #tempEmergencyEncounters
CREATE TABLE #tempEmergencyEncounters (
encounter_id NVARCHAR(100),
patient_id NVARCHAR(100),
enc_start DATE,
enc_end DATE,
race NVARCHAR(50),
gender NVARCHAR(50),
payer_coverage FLOAT,
insurance_name NVARCHAR(50)
);

INSERT INTO #tempEmergencyEncounters
SELECT
e.id AS encounter_id,
p.id AS patient_id,
e.start,
e.stop,
p.race,
p.gender,
e.PAYER_COVERAGE,
pay.name
FROM encounters e
LEFT JOIN patients p 
ON e.patient = p.id
LEFT JOIN payers pay 
ON e.payer = pay.id
WHERE e.encounterclass = 'Emergency'

SELECT 
insurance_name,
race,
COUNT(encounter_id) AS total_emergency_enc,
SUM(
	CASE 
		WHEN gender = 'M' THEN 1 
		ELSE 0 
	END) AS male_patient_enc,
SUM(
	CASE 
		WHEN gender = 'F' THEN 1 
		ELSE 0 
	END) AS female_patient_enc,
COUNT(DISTINCT patient_id) AS unique_patients,
ROUND(SUM(payer_coverage), 2) as insurance_coverage
FROM #tempEmergencyEncounters
GROUP BY insurance_name, race
ORDER BY insurance_name, race


---- 2D. Create views for visualizations
CREATE VIEW pat_med_visuals AS
SELECT 
m.patient,
m.payer,
m.encounter,
m.description,
m.BASE_COST,
m.PAYER_COVERAGE as pc1,
m.dispenses,
m.TOTALCOST,
CAST(e.start AS datetime) AS enc_start,
CAST(e.stop AS datetime) AS enc_stop,
e.encounterclass,
e.base_encounter_cost,
e.total_claim_cost,
e.payer_coverage AS pc2,
e.reasondescription,
p.first,
p.last,
p.race,
p.ethnicity,
p.gender,
p.address,
p.city,
p.state,
p.county,
p.zip,
p.lat,
p.lon,
p.age,
pay.name,
pay.amount_covered,
pay.amount_uncovered,
DATEPART(YEAR, e.start) AS encounter_year,
DATEDIFF(minute, e.start, e.stop) AS wait_min
FROM medications m
INNER JOIN encounters e
ON m.encounter = e.id
INNER JOIN patients p
ON m.patient = p.id
LEFT JOIN payers pay
ON m.payer = pay.id
WHERE DATEPART(YEAR, e.start) >= '2010'



