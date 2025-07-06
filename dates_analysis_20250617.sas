
/*
 *------------------------------------------------------------------------------
 * Program Name:  DATES_ANALYSIS_20250617
 * Author:        Mikhail Hoskins
 * Date Created:  06/17/2025
 * Date Modified: 
 * Description:   We want to evaluate date as specimen date versus report date over the last decade + in NC. 
 *				  
 *
 * Inputs:       case.sas7bdat , case_phi.sas7bdat , Admin_question_package_addl.sas7bdat : Z:\YYYYMMDD , risk factors from NCEDSS
 * Output:       .
 * Notes:        Program pulls all MDRO. 
 *				 Annotations are between /* to help guide. If the code doesn't work or numbers don't align, check here: 
 *				 https://github.com/NC-DPH/Communicable-Disease-Dashboards/blob/main/NCD3v2%20In%20Progress.sas
 *					
 *
 *------------------------------------------------------------------------------
 */


/*Step 1: set your pathway. Must have Z drive (or however you are mapped to denormalized tables) access.*/
libname denorm 'Z:\20250301'; /*Select the file name you want from the Z drive. Format is YYYYMMDD. Tables are created monthly*/
libname local 'C:\Users\mhoskins1\Desktop\Work Files';

/*Step 1a: set your date range in the format specified.*/
%let start_dte = 01JAN12; /*Set your start date for range of values DDMMYY*/
%let end_dte = 31DEC24; /*Set your end date for range of values DDMMMYY*/


/*Step 2: Table 1 GAS and administrative package questions (date reported variable)*/
proc sql;
create table CASE_COMBO as
select 
	s.*, a.EVENT_STATE,
	b.RPTI_SOURCE_DT_SUBMITTED

from denorm.case 

	as s left join denorm.case_PHI as a on s.case_id=a.case_id
	left join denorm.Admin_question_package_addl as b on s.case_id=b.case_id

where s.CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable")
	and s.type in ("STRA" , "CRE", "CAURIS") 
	and s.REPORT_TO_CDC = 'Yes';

quit;


/*Step 3: Table 2: Confine to certain key variables. You can add and subtract variables here to fit your needs if necessary*/
proc sql;
create table GAS_updated as
select 
		TYPE, 


		/*don't delete this section, it's a logic path for how the state creates an event date based on submission, lab, and symptom dates*/
	case 
	    when MMWR_DATE_BASIS ne . then MMWR_DATE_BASIS
		when SYMPTOM_ONSET_DATE ne . then SYMPTOM_ONSET_DATE
	    when (SYMPTOM_ONSET_DATE = . ) and  RPTI_SOURCE_DT_SUBMITTED  ne . then RPTI_SOURCE_DT_SUBMITTED
	    else datepart(CREATE_DT)
	    end as EVENT_DATE format=DATE9., 

		/*don't delete this section, it's a logic path for how the state creates an event date based on submission, lab, and symptom dates*/
	case 
		when SYMPTOM_ONSET_DATE ne . then SYMPTOM_ONSET_DATE
	    when (SYMPTOM_ONSET_DATE = . ) and  RPTI_SOURCE_DT_SUBMITTED  ne . then RPTI_SOURCE_DT_SUBMITTED
	    else datepart(CREATE_DT)
	    end as EVENT_DATE_2 format=DATE9., 

	year(calculated EVENT_DATE) as Year, 
	month(calculated EVENT_DATE) as Month, 
	QTR(calculated EVENT_DATE) as Quarter

from CASE_COMBO
where calculated EVENT_DATE >= "&start_dte."d and calculated EVENT_DATE <= "&end_dte."d
	and STATUS = 'Closed'
	/*and STATE in ('NC' ' ')*/
order by TYPE_DESC, YEAR, OWNING_JD;
quit;


proc print data=local.laboratory_denormalized_table (obs=10);run;

/*Select only what we need from the lab specimen tables*/
proc sql;

create table keep_only as
select distinct
	
	CASE_ID,
	SPECIMEN_DT as EVENT_DATE,
	case when SPECIMEN_DT not in (.) then 1 else 0 end as specdt_flag,
	PRODUCT as TYPE,
	case when result not in ("Negative", "Inconclusive", "Not detected", "Unknown" , "" , "Done" , "No reportable organisms identified at this time"
								"Normal flora", "Pending") then 1 else 0 end as pos_result,
	result

from local.laboratory_denormalized_table
	where PRODUCT in ("STRA", "CRE", "CAURIS") 
	having pos_result in (1)
;
quit;



proc freq data=keep_only ;tables result /norow nocol nopercent;run;



data spec_dte_analysis_2;
set GAS_updated Keep_only;

run;

proc sql;
create table date_long as
select distinct

	CASE_ID,
	EVENT_DATE as date_new,
	case when specdt_flag in (1) then "Specimen" else "Report" end as identity_spec "Spec flag = 1",
	TYPE


from spec_dte_analysis_2;
quit;

proc print data=date_long (obs=100);run;

ods graphics / noborder;
proc sgplot data=date_long noborder;

  histogram date_new / group=identity_spec transparency=0.5;     
  density date_new / type=kernel group=identity_spec; /* overlay density estimates */

  	xaxis label="Year" ;
	keylegend  / across=1 position=topleft location=Inside;

where date_new GE ('01JAN2024'D) and date_new LE ('31DEC2024'D) and type in ('CAURIS');   

run;


