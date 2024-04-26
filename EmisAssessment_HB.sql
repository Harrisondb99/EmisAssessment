Use Test; --This is what I called my database. It will require changing for your own database name

--ALTER TABLE [dbo].[patient]
--ADD [postal_area]  AS (left([postcode],patindex('%[0-9]%',[postcode])-(1))) PERSISTED   --This was required to be ran once only initially to solve the area code issue -- It is returning a list of all postal areas using only the inital letters and not numbers in a postcode. 

--CREATE NONCLUSTERED INDEX [index_1]
--ON [dbo].[observation] ([end_date],[registration_guid])
--INCLUDE ([snomed_concept_id])                                --This was also ran once, solved the load time issue (from 6.3mins to 0.01sec) (Discovered using the show execution plan tab)


WITH 

cte_patients_by_postcode(
	Postal_Area,
	Gender,
	Gender_Count
)

AS (
	SELECT 
		TOP 10000
		postal_area,
		gender,
		COUNT(*) AS gender_count
	FROM 
		patient
	WHERE 
		postcode IS NOT NULL
		--AND gender NOT IN ('Unknown','Indeterminate') -- This can be uncommented to exclude those that did not set gender to male or female.
	GROUP BY 
		postal_area,
		gender
	ORDER BY 
		gender_count DESC
), --This CTE is used to list the populations from each postcode area. Will later be used to take only those from the top 2 areas.


cte_top_2_postalarea (
	Postal_Area
)

AS (
	SELECT TOP 2 
		postal_area 
	FROM (
		SELECT 
			TOP 1000
			postal_area
		FROM 
			patient
		WHERE 
			postcode IS NOT NULL 
		GROUP BY 
			postal_area
		ORDER BY 
			COUNT(*) DESC
	) pa

), --This CTE uses the previous CTE (cte.patients_by_postcode) to take the top 2 distinct areas and list them.


cte_alive_patients (
	Registration_GUID,
	Patient_ID,
	Fullname,
	Postcode,
	Postal_Area,
	Date_Of_Birth,
	Age,
	Gender
)

AS (
	SELECT
		p.registration_guid,
		p.patient_id,
		p.patient_givenname + ' ' + patient_surname, --This was for formatting to make the names show better. Creating 1 column instead of 2. 
		p.postcode,
		p.postal_area,
		p.date_of_birth, 
		DATEDIFF(YEAR, p.date_of_birth, GETDATE()), --This was done to get an accurate and updating age for each patient instead of a static value. 
		p.gender
	FROM 
		patient p
	WHERE 
		p.date_of_death is NULL --Only pulling alive patients

), --This CTE creates a list of all patient data I'll need for the final output, but only includes those that have not passed away. This filters down the required data to improve run speed of the query. 


cte_observations_with_asthma (
	Registration_GUID
)

AS (
	SELECT
		DISTINCT
		o.registration_guid --Only pulling one row for each unique reg.ID
	FROM
		observation o
		 INNER JOIN clinical_codes c ON c.snomed_concept_id = o.snomed_concept_id --This allows for the refset id from c to be used to filter data from o. 
	WHERE
		c.refset_simple_id = 999012891000230104 --The id for athsma
		AND o.end_date is NULL 
), --CTE creating a list of all patients with unresolved athsma. 


cte_observations_who_are_smokers (
	Registration_GUID
)

AS (
	SELECT
		DISTINCT
		o.registration_guid --Only pulling one row for each unique reg.ID
	FROM
		observation o
		 INNER JOIN clinical_codes c ON c.snomed_concept_id = o.snomed_concept_id --This allows for the refset id from c to be used to filter data from o.
	WHERE
		c.refset_simple_id = 999004211000230104
		AND o.end_date is not NULL
), --CTE to create a list of patients who actively smoke
 
cte_observations_who_are_less_than_40kg (
	Registration_GUID
)

AS (
	SELECT
		DISTINCT
		o.registration_guid --Only pulling one row for each unique reg.ID
	FROM
		observation o
	WHERE
		o.snomed_concept_id = 27113001 --id for patients under 40kg
),

cte_observations_with_COPD_diagnosis (
	Registration_GUID
)

AS (
	SELECT
		DISTINCT
		o.registration_guid --Only pulling one row for each unique reg.ID
	FROM
		observation o
		 INNER JOIN clinical_codes c ON c.snomed_concept_id = o.snomed_concept_id --This allows for the refset id from c to be used to filter data from o.
	WHERE
		c.refset_simple_id = 999011571000230107
		AND o.end_date is NULL
) --CTE for creating a list of all patients with unresolved COPD

SELECT --
	DISTINCT
	m.emis_registration_organisation_guid AS Organisation_GUID,
	p.Registration_GUID,
	p.Patient_ID,
	p.Fullname,
	p.PostCode,
	p.Age,
	p.Gender
FROM 
	cte_alive_patients p
	 INNER JOIN cte_observations_with_asthma oa ON p.Registration_GUID = oa.Registration_GUID -- 																				
	 LEFT JOIN medication m ON m.registration_guid = p.Registration_GUID --Left join used to only pull from the list of alive patients to reduce data needing to be filtered --Improves run time slightly. 

WHERE --The following utilises the CTE's created to include/exclude the relevant patients.
	 p.Registration_GUID NOT IN (SELECT Registration_GUID FROM cte_observations_who_are_smokers) -- filter out smokers
    AND p.Registration_GUID NOT IN (SELECT Registration_GUID FROM cte_observations_who_are_less_than_40kg) -- filter out patients whose weight is less than 40kg
	AND p.Registration_GUID NOT IN (SELECT Registration_GUID FROM cte_observations_with_COPD_diagnosis) --Filter out patients who have a COPD diagnosis
	--AND (p.Postal_Area = 'LS') OR (p.Postal_Area = 'WF') --Backup plan for if the addition of the variable postcode area does not work. 
	AND p.postal_area IN (SELECT Postal_Area FROM cte_top_2_postalarea)-- Only include patients from the highest 2 populated areas. (Can change out for above line if neccesary)

ORDER BY 
	Patient_ID --Seemed the most logical id to order by. Can be changed as required. 
