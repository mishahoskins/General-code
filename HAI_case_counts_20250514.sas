
/*
 *------------------------------------------------------------------------------
 * Program Name:  HAI_case_counts_20250326 
 * Author:        Mikhail Hoskins
 * Date Created:  03/26/2025
 * Date Modified: 05/14/2025 (added CRE mechanism and organism table)
 * Description:   Case count data pull from monthly denormalized tables. Easy to run in office, can take longer
				  on VPN. 
 *
 * Inputs:       case.sas7bdat , case_phi.sas7bdat , Admin_question_package_addl.sas7bdat : Z:\YYYYMMDD
 * Output:       none, frequency table at end of program
 * Notes:        Program pulls reportable HAIs. CRE, Cauris, and GAS. ***CRE will be updated in the denormalized tables to 
 *				 reflect CPO rule change at some point in 2025. Will need to update table #2 (roughly line 54) when this happens.
 *				 Annotations are between /* to help guide. If the code doesn't work or numbers don't align, check here: 
 *				 https://github.com/NC-DPH/Communicable-Disease-Dashboards/blob/main/NCD3v2%20In%20Progress.sas
 *
 *------------------------------------------------------------------------------
 */


/*Step 1: set your pathway. Must have Z drive (or however you are mapped to denormalized tables) access.*/
libname denorm 'Z:\20250603'; /*Select the file name you want from the Z drive. Format is YYYYMMDD. Tables are created monthly*/
/*Step 1a: set your date range in the format specified.*/
%let start_dte = 01JAN23; /*Set your start date for range of values DDMMYY*/
%let end_dte = 28MAY25; /*Set your end date for range of values DDMMMYY*/



/*From here below should run without touching anything*/

/*Step 2a: Table 1 GAS, CAURIS, and administrative package questions (date reported variable)*/
proc sql;
create table CASE_COMBO as
select 
	s.*, a.EVENT_STATE,
	b.RPTI_SOURCE_DT_SUBMITTED

from denorm.case 

	as s left join denorm.case_PHI as a on s.case_id=a.case_id
	left join denorm.Admin_question_package_addl as b on s.case_id=b.case_id

where s.CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable")
	and s.type in ( "CAURIS", "STRA") 
	and s.REPORT_TO_CDC = 'Yes';

quit;

/*Step 2b: Table 2: CRE (soon to be CPO). Extra step we want all events, even those NOT reported to CDC*/
proc sql;
create table CASE_COMBO_2 as
select 
	s.*, a.EVENT_STATE,
	b.RPTI_SOURCE_DT_SUBMITTED

from denorm.case 

	as s left join denorm.case_PHI as a on s.case_id=a.case_id
	left join denorm.Admin_question_package_addl as b on s.case_id=b.case_id

where s.CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable")
	and s.type in ("CRE") 
	and s.REPORT_TO_CDC not in ('');

quit;

proc sql;
create table CASE_COMBO_3 as
select

	quit;

proc contents data=denorm.case_PHI ;run;


/*Step 3: Merge the two HAI sets to get one set with CRE, CAURIS, and GAS*/
data CASE_COMBO_SUB;
set CASE_COMBO CASE_COMBO_2;
run;

/*Step 4: Table 3: Confine to certain key variables. You can add and subtract variables here to fit your needs if necessary*/
proc sql;
create table HAI_updated as
select distinct *, /*Distinct here for unique values, can add or remove variables as needed*/
		OWNING_JD,
		TYPE, 
		TYPE_DESC, 
		CLASSIFICATION_CLASSIFICATION, 
		CASE_ID,
		REPORT_TO_CDC,

		input(MMWR_YEAR, 4.) as MMWR_YEAR, 
		MMWR_DATE_BASIS, 

		count(distinct CASE_ID) as Case_Ct label = 'Counts', 
		'Healthcare Acquired Infection' as Disease_Group,
		AGE, 
		GENDER, 
		HISPANIC, 
		RACE1, 
		RACE2, 
		RACE3, 
		RACE4, 
		RACE5, 
		RACE6,
/*This piece should match exactly or almost exactly to the dashboard code found here: https://github.com/NC-DPH/Communicable-Disease-Dashboards/blob/main/NCD3v2%20In%20Progress.sas
		some of the variable names may be different but the counts need to align*/

		/*don't delete this section, it's a logic path for how the state creates an event date based on submission, lab, and symptom dates*/
	case 
	    when MMWR_DATE_BASIS ne . then MMWR_DATE_BASIS
		when SYMPTOM_ONSET_DATE ne . then SYMPTOM_ONSET_DATE
	    when (SYMPTOM_ONSET_DATE = . ) and  RPTI_SOURCE_DT_SUBMITTED  ne . then RPTI_SOURCE_DT_SUBMITTED
	    else datepart(CREATE_DT)
	    end as EVENT_DATE format=DATE9., 

	year(calculated EVENT_DATE) as Year, 
	month(calculated EVENT_DATE) as Month, 
	QTR(calculated EVENT_DATE) as Quarter,
/*Additional variables for MDRO report*/
	SYMPTOM_ONSET_DATE, 
	DISEASE_ONSET_QUALIFIER, 
	DATE_FOR_REPORTING,
	RPTI_SOURCE_DT_SUBMITTED, 
	CREATE_DT, 
	STATUS

from CASE_COMBO_sub
where calculated EVENT_DATE >= "&start_dte."d and calculated EVENT_DATE <= "&end_dte."d
	and STATUS = 'Closed'
	/*and STATE in ('NC' ' ')*/
order by TYPE_DESC, YEAR, OWNING_JD;


quit;

data labs_clean;
set denorm.laboratory_dd_table_cre;

	if CRE_CARB_PRODUCE_MECHANISM = '' and CRE_CARB_ORGANISM = '' then delete;
run;

proc sql;
create table labs_clean_2 as
select distinct

	case_ID,
	CRE_CARB_ORGANISM,
	CRE_CARB_PRODUCE_MECHANISM


from labs_clean
;
quit;

/*Now join them all with table 1 from the denormalized, confirmed, deduplicated, and reported to CDC count (table 4 (final))*/
proc sql;
/*patient outcome, surgical experience, LTCF residency, IV drug use variables add here*/
create table CRE_mech as
select 

	a.*,
	b.CRE_CARB_ORGANISM,
	b.CRE_CARB_PRODUCE_MECHANISM

from HAI_updated as a 
	left join labs_clean_2 as b on a.case_ID = b.case_ID

	where a.type in ("CRE")
;

quit;


/*Step 5: Frequency table of organism and mechanism for CRE*/ 
proc freq data=CRE_mech; tables CRE_CARB_PRODUCE_MECHANISM*year /norow nocol nopercent nocum;run;

/*Frequency table of counts*/
proc freq data=HAI_updated; tables type TYPE*YEAR / norow nocol nocum nopercent;run;


/*fin*/
