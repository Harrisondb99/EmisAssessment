# EmisAssessment
My submission for the Emis assessment required for the Data Analyst position. If you have any suggestions for where I could improve this query I'd love to hear them, either through the interview or as feedback. 


**Progression Notes;**

I combined all of the relevant csv files together within python visual studio before using the flat file wizard to import all data into my studio. 
The following is a list of changes that were required to be made within the wizard before I could use the data;

**Medication;**

Changed dose from nvarchar(50) to nvarchar(max) <br />
Changed reimburse type to allow nulls <br />
Changed emis_mostrecent_issue_date to allow nulls <br />
Changed end date to allow nulls <br />
Changed number_authorised to nvarchar(50) <br />
Changed max_nextissue_days to nvarchar(50) <br />
Changed min_nextissue_days to nvarchar(50) <br />
Changed emis_original_term to nvarchar(MAX) <br />
Changed emis_drug_guid to nvarchar(MAX) <br />
Changed emis_issue_method to nvarchar(MAX) <br />
Changed estimated_nhs_cost to nvarchar(MAX) <br />
Changed consultation_source_emis_code_id to nvarchar(MAX) <br />
Changed consultation_source_emis_original_term to nvarchar(MAX) <br />
Changed emis_encounter_guid to nvarchar(MAX) <br />
Changed exa_encounter_guid to nvarchar(MAX) <br />
Changed emis_code_id to allow nulls <br />
Changed authorisedissues_authorised_date to allow nulls <br />
Changed emis_medication_status to allow nulls <br />
Changed number_of_issues to allow nulls <br />

**Observations;**

Changed effective_date to allow null<br />
Changed other_display to nvarchar(MAX)<br />
Changed emis_original_term to nvarchar(MAX)<br />
Changed comparator to nvarchar(MAX)<br />

Both clincal codes and patient required no changes. <br />

All nvarchar values were tested at lower amounts before increasing to MAX when neccesary.<br />


**Task 1-**

**Post Code Areas

I initially was indecisive with what defined a postcode area since I found different answers online. <br />
  -I decided to stick with only using the first letters of a postcode even though this was harder to query, this was because it seemed to create a more specific area code for each population. <br />
  -The alteration to my query required research into potential functions, leading me to find the PATINDEX function, allowing me to only pull the first X amount of letters in a postcode, and stopping when a number was found. <br />

I chose to include the indeterminate and unknown gender patients within the populations as they made up a significant amount of the population. However I also have shown in the query a commented out line that will exclude these patients if required. <br />

-When trying to incorporate the query regarding postcode area’s into my final query, I wanted it to change based on the top populated areas and not a static 2 areas I’d manually change based on the results of my Task 1 query. I tried to resolve this using the same query I'd written previously, but as you can see from my penultimate github update, it returned different values each time due to the TOP 10000 value. <br />
  -To resolve this issue, I realised I could create a new column within the patient table, storing all of the 'names' of the postcode areas as distinct names in order of population.<br />
  -This allowed me to use the CTE method I use later in the query to pull only the top 2 most populated areas and resolved the issue. <br />
Using this method also significantly slowed my query down, a problem that admittedly took a long time to understand. I ran my query without the postcode area requirement and it removed the issue. <br />
  -To resolve this I discovered the execution plan and created an index within the observation table. (After spending a lot of time looking into indexes)<br />
    -I've left this commented out at the top of my query. It requires being ran once to store the neccesary data and significantly decrease run times. <br />
  -This is one area I'd love to hear feedback on specifically as I'd like to know if there was a simpler way to improve run times without the need for an index. <br />
  
**Task 2-**

**Important notes**

**Medications**

I found an issue in the assessment requirements regarding both the medication list and the opt-out conditions that I wasn't able to resolve. I believe that this is an issue with the data itself but I am very open to hearing if I may have done something incorrectly. <br />
  -Regarding the medication list, after using the provided clinical code id's to gather the code_id, parent_code_id and refset_simple_id.<br />
    -For the listed medications, all of them had a NULL value for their refset_id, which is what I would have used to compare the values on other tables. <br />
    -The medications all also had their code_id and parent_code_id as identical values. <br />
    -After searching the observation and medication tables I wasn't able to find any data regarding the listed medications/medications using the listed as ingredients. <br />
    -My only potential solution to this was to use the names of the ingredients to find the medications, however I decided against this as it felt too loose of a condition and was very innacurate. <br />
If I was to do this, I'd have created a CTE (explained further down this list) and made a list of all patients who are on the relevant medications. Then in my final where statement, I'd have included that the patient needed to be present within this list. <br />

**Opt-Outs**

The only four columns that referenced a patients opt-out condition are given very confusing names within the data. Such as 'opt_out_93c1_flag'. This made it very difficult to understand which opt-out's were relevant to what was required in this assessment. <br />
  -I looked up opt-out codes online and was able to find that 9nu referenced a type 1 opt out, which potentially linked to the 'Opt_out_9nu0_flag' column. <br />
  -I chose to not include a line for this in my query due to the ambiguity of it.<br />
    -If I were to include this in the query, for the relevant column I'd have included a WHERE opt_out_X is False (Meaning that the patient has not opted out)<br />

**Common Table Expressions (CTE's)**

After an initial struggle to include/exclude all of the relevant data using a series of complicatdd joins and where statements, I discovered CTE's. Saving a lot of run time for the query and my own confusion.<br />
  -I used a CTE for every single condition relevant to the assessment (Athsma, COPD, smoker etc). <br />
    -This created a temporary table within the query to list the Registation_GUID (the unique id for each patient) for every distinct patient that met a specific condition.<br />
      -For example, this created a CTE for every patient that has an unresolved COPD diagnosis. Storing that list of Registration_GUID's for later use in the query. <br />
  -I've commented throughout my query as to what each CTE is being used for.<br />
  -This is another area I'd be interested to hear if I could have used an alternate or more optimal method. I had no issues with the run speed of this even without the inclusion of an index. <br />


**Alive Patients**

This is something that I initially forgot to include in my query. I created a CTE with all the columns I planned to use in the final output, but with the WHERE of - date_of_death is NULL. <br />
  -This created a temporary list of patients that were alive and presented only the relevant information. <br />
    -This was done to try and reduce run time as it required less filtering when this CTE was called on for the final list of WHERE statements.<br />

**Patient Age/Name**

I had a similar realisation toward the end of my query writing when I noticed near all patients had an age of 0 with a DOB in the 2022 (we'll ignore how many of these patients are smokers at such a young age)<br />
  -I included a short line in my CTE for alive patients to change the age from the static value in the age column to an up to date value. (DATEDIFF(YEAR,p.date_of_birth, GETDATE())<br />

I did the same for the patient's name, rather than showing two seperate columns for each patient I chose to combine them into one new column called Fullname. <br />
  -This had no real effect on the query but I believe it makes the output easier to read. <br />

  **Patient Weight (Added as a final adjustment)**

  I realised just before submission that the snomed_concept_id for the patients under 40kg is related to 4 different emis_term's. However, even with research online I'm not 100% certain as to which of these specifically relates to the correct filter of weight. I also noticed the column for range_lower and range_upper are potentially patient weights ranges, however without any certainty on this due to no unit of measurement I haven't filtered for those with a range_upper to be below 40 (kg presumably).


**Query Testing**

I went through the query and for each CTE created, I ran these on a seperate query to ensure the correct patients were being outputted. <br />
I built this up one by one to check that the addition of each CTE was not outputting incorrect patients. <br />
After the fix for the postcode area (described above) all CTE's were returning the correct patients, with the final output in the main query meeting the assessment criteria. <br />
  -This was checked by picking out patients at random from the outputted list and checking them against each condition individually. <br />


**Final Remarks**

I greatly enjoyed this assessment and the challenge to filter out an unfamiliar set of data to meet the required conditions. I hope that my comments and read.me provide a sufficient amount of description for my query, but If there is anything I can clarify I'm happy to answer any questions.<br />
I'd love any feedback on this query as to how I could have optimised the methods I used or if anything is incorrect!

Thank you for the opportunity to do this assessment and I look forward to hearing from you! <br />
-Harrison B
