Use Test; -- This is what I called my database, it allows for me to automatically switch over when running this query. This will need changing if using a different pc. 


WITH 
cte_patients_by_postcode(
	Postcode_Area,
	Gender,
	Gender_Count)
AS (
	SELECT 
		TOP 10000 --Required for the order by function to work. This is the cause of the significant slow down in the query. 
		LEFT(postcode, PATINDEX('%[0-9]%', postcode) - 1) AS postcode_area, --This line is telling the query to only use the first letters in the postcode, no numbers. This can be changed by just using a Left, 2 function regardless of letters/numbers. 
		gender,
		COUNT(*) AS gender_count --This is my population of each gender in each area code
	FROM 
		patient
	WHERE 
		postcode IS NOT NULL
	-- I was unsure whether to include the non-specified genders, to remove them add in this line >	AND gender NOT IN ('Unknown','Indeterminate') --
	GROUP BY 
		LEFT(postcode, PATINDEX('%[0-9]%', postcode) - 1),
		gender --This groups the area code results and genders togethers.
	ORDER BY 
		SUM(COUNT(*)) OVER (PARTITION BY LEFT(postcode, PATINDEX('%[0-9]%', postcode) - 1)) DESC,
		gender_count DESC --This is telling the CTE to list the results based on the highest population before it uses the area codes.
),


cte_top_2_postalarea (
	Postal_Area
)
AS (
	SELECT DISTINCT TOP 2  
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
), -- This CTE is pulling together all patients with an athsma diagnosis that has not been resolved. These will be included in the final output.



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
		and o.end_date is not null
), -- This CTE gives a list of all patients meeting the current smoker condition, and should be excluded from the final result


cte_observations_who_weight_less_than_40kg (
	Registration_GUID
)
AS (
	SELECT 
		DISTINCT
		o.registration_GUID
	FROM
		observation o
		INNER JOIN clinical_codes c on c.snomed_concept_id = o.snomed_concept_id
	WHERE
		o.snomed_concept_id = 27113001
), --This CTE returns a list of all patients who weigh less than 40kg and should be excluded from the final result.


cte_observations_who_unresolved_COPD (
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
		c.refset_simple_id = 999011571000230107
		and o.end_date is not null 
 ) -- This CTE returns a list of all patients who have an unresolved case of COPD, and should be excluded


SELECT --This final query is the output, pulling together all the relevant information from the CTE's 
	DISTINCT -- So that we only get one result per person
	m.emis_registration_organisation_guid AS Organisation_GUID,
	p.Registration_GUID,
	p.Patient_ID,
	p.Fullname,
	p.PostCode,
	p.Age,
	p.Gender
FROM 
	cte_alive_patients p
	 INNER JOIN cte_observations_with_asthma oa ON p.Registration_GUID = oa.Registration_GUID -- Only include people with asthma. --Could I do this a different way?
	 LEFT JOIN medication m ON m.registration_guid = p.Registration_GUID -- This is pulling together the relevant rows from various tables.
 
WHERE
	p.Registration_GUID NOT IN (SELECT Registration_GUID FROM cte_observations_who_are_smokers) -- Filter out smokers using the CTE
	AND p.Registration_GUID NOT IN (SELECT Registration_GUID FROM cte_observations_who_weight_less_than_40kg)-- Excludes people who weigh less than 40kg
	AND p.Registration_GUID NOT IN (SELECT registration_GUID FROM cte_observations_who_unresolved_COPD) --Excludes those with unresolved COPD, ingnoring those that have been resolved in the past
	AND	LEFT(postcode, PATINDEX('%[0-9]%', p.postcode) - 1) IN (SELECT Postal_Area FROM cte_top_2_postalarea) -- Only include people in highest 2 postal areas by checking the value of the area code = the values given from the earlier test for the top 2 populations. 
 
ORDER BY 
	Patient_ID
