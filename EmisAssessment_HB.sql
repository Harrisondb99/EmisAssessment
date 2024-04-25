WITH 
cte_patients_by_postcode(
	Postcode_Area,
	Gender,
	Gender_Count)
AS (
	SELECT 
		TOP 10000
		LEFT(postcode, PATINDEX('%[0-9]%', postcode) - 1) ASpostcode_area,
		gender,
		COUNT(*) AS gender_count
	FROM 
		patient
	WHERE 
		postcode IS NOT NULL
	-- I was unsure whether to include the non-specified genders, to remove them add in this line >	AND gender NOT IN ('Unknown','Indeterminate') --
	GROUP BY 
		LEFT(postcode, PATINDEX('%[0-9]%', postcode) - 1),
		gender
	ORDER BY 
		SUM(COUNT(*)) OVER (PARTITION BY LEFT(postcode, PATINDEX('%[0-9]%', postcode) - 1)) DESC,
		gender_count DESC
),
cte_top_2_postalarea (
	Postal_Area
)
AS (
	SELECT TOP 2 
		Postcode_Area 
	FROM
		cte_patients_by_postcode cpbp
	GROUP BY
		Postcode_Area 
),
cte_alive_patients (
	Registration_GUID,
	Patient_ID,
	Fullname,
	Postcode,
	Date_Of_Birth,
	Age,
	Gender
)
AS (
	SELECT
		p.registration_guid,
		p.patient_id,
		p.patient_givenname + ' ' + patient_surname, 
		p.postcode,
		p.date_of_birth, 
		DATEDIFF(YEAR, p.date_of_birth, GETDATE()), 
		p.gender
	FROM 
		patient p
	WHERE 
		p.date_of_death is NULL
),
cte_observations_with_asthma (
	Registration_GUID
)
AS (
	SELECT
		DISTINCT
		o.registration_guid
	FROM
		observation o
		 INNER JOIN clinical_codes c ON c.snomed_concept_id = o.snomed_concept_id
	WHERE
		c.refset_simple_id = 999012891000230104
		AND o.end_date is NULL
),
cte_observations_who_are_smokers (
	Registration_GUID
)
AS (
	SELECT
		DISTINCT
		o.registration_guid
	FROM
		observation o
		 INNER JOIN clinical_codes c ON c.snomed_concept_id = o.snomed_concept_id
	WHERE
		c.refset_simple_id = 999004211000230104
)
 
 
SELECT
	DISTINCT
	m.emis_registration_organisation_guid ASOrganisation_GUID,
	p.Registration_GUID,
	p.Patient_ID,
	p.Fullname,
	p.PostCode,
	p.Age,
	p.Gender
FROM 
	cte_alive_patients p
	 INNER JOIN cte_observations_with_asthma oa ON p.Registration_GUID = oa.Registration_GUID -- only include peole with asthma
	 LEFT JOIN medication m ON m.registration_guid = p.Registration_GUID
 
WHERE
	p.Registration_GUID NOT IN (SELECT Registration_GUID FROM cte_observations_who_are_smokers) -- filter out smokers
	AND	LEFT(postcode, PATINDEX('%[0-9]%', p.postcode) - 1) IN (SELECT Postal_Area FROM cte_top_2_postalarea) -- Only include people in highest postal areas
 
ORDER BY 
	Patient_ID

--To do list
	--Create CTE for weight, COPD unresolved
	--Opt out list?
	--Medication issue
