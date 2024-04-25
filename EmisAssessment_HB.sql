Use Test
go

SELECT 
    LEFT(postcode, PATINDEX('%[0-9]%', postcode) - 1) AS postcode_area,
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
	gender_count DESC;

--Even without the unknown and indeterminate genders, LS is the highest population by far, followed by WF--