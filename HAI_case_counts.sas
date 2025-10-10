
/*
 *------------------------------------------------------------------------------
 * Program Name:  HAI_case_counts_20250326 
 * Author:        Mikhail Hoskins
 * Date Created:  03/26/2025
 * Date Modified: 08/12/2025 (August updates)
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
libname denorm 'Z:\20251001'; /*Select the file name you want from the Z drive. Format is YYYYMMDD. Tables are created monthly*/
libname output 'T:\HAI\Code library\Epi curve example\SASData';/*output path for sas7bdat file*/
/*Step 1a: set your date range in the format specified.*/
%let start_dte = 01jan15; /*Set your start date for range of values DDMMYY*/
%let end_dte = 25Sep25; /*Set your end date for range of values DDMMMYY*/



/*From here below should run without touching anything*/

/*Step 2a: Table 1 GAS, CAURIS, and administrative package questions (date reported variable)*/
/*Get C.auris and STRA (GAS)*/
proc sql;
create table CASE_COMBO as
select 

	s.*, /*a.State*/
	a.EVENT_STATE, 
	b.RPTI_SOURCE_DT_SUBMITTED

from DENORM.CASE as s left join Denorm.CASE_PHI as a on s.case_id=a.case_id
		left join Denorm.Admin_question_package_addl as b on s.case_id=b.case_id

	where s.CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable")
			and s.type in ("CAURIS", "STRA"/*, "SAUR", "TSS", "TSSS"*/)
			and s.REPORT_TO_CDC = 'Yes'
;

quit;


/*Get CRE*/
proc sql;
create table CASE_COMBO_2 as
select 

	s.*, 
	a.EVENT_STATE, 
	b.RPTI_SOURCE_DT_SUBMITTED

from DENORM.CASE as s left join Denorm.CASE_PHI as a on s.case_id=a.case_id
		left join Denorm.Admin_question_package_addl as b on s.case_id=b.case_id

	where s.CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable")
			and (s.type = "CRE" or s.type = "CPO");	*CRE became CPO event in May 2025;
/*Removed the REPORT_TO_CDC=”Yes” filter for Carbapenem-resistant Enterobacteriaceae*/

quit;


/*BREAK*/

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
		BIRTH_DATE, 
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
	/*and STATUS = 'Closed'*/
	/*and STATE in ('NC' ' ')*/
order by TYPE_DESC, YEAR, OWNING_JD;


quit;

proc freq data=HAI_updated; tables type*year /norow nocol nopercent nocum; run;

dm 'odsresults; clear';

data output.analysis;
set HAI_updated;
run;

/*Begin CPO/CRE mechanism extract*/
/*Take all CPOs and search for mechanisms in the lab results where the result is confirmed*/
proc contents data=denorm.laboratory_dd_table_cre order=varnum;run;


proc freq data=denorm.laboratory_dd_table_cre ;tables CRE_CARB_PRODUCE_MECHANISM / norow nocol nopercent; where LAB_CREATE_DATE GE ('01JAN25'd);run;

proc sql;
create table CPO_mechext as
select distinct

	Case_ID,
	CRE_CARB_ORGANISM,
	CRE_CARB_PRODUCE_MECHANISM,


/*Take all CPOs and search for MECHANISMS in the lab results where the result is confirmed*/
case  when product in ("CPO") and TEST like '%KPC%' and result not in ('Not Detected' , 'Not detected', 'Negative' , 'Unknown') then 'KPC'
		  when product in ("CPO") and  TEST like '%NDM%' and result not in ('Not Detected' , 'Not detected', 'Negative' , 'Unknown')  then 'NDM'
		  when product in ("CPO") and  TEST like '%OXA-48%' and result not in ('Not Detected' , 'Not detected', 'Negative' , 'Unknown')  then 'OXA-48' 
		  when product in ("CPO") and  TEST like '%OXA-23%' and result not in ('Not Detected' , 'Not detected', 'Negative' , 'Unknown')  then 'OXA-23'
		  when product in ("CPO") and  TEST like '%OXA-24%' and result not in ('Not Detected' , 'Not detected', 'Negative' , 'Unknown')  then 'OXA-24'  
		  when product in ("CPO") and  TEST like '%OTHER%' and result not in ('Not Detected' , 'Not detected', 'Negative' , 'Unknown')  then 'Other' 
		  when product in ("CPO") and  TEST like '%VIM%' and result not in ('Not Detected' , 'Not detected', 'Negative' , 'Unknown')  then 'VIM' 
		  when product in ("CPO") and  TEST like '%IMP%' and result not in ('Not Detected' , 'Not detected', 'Negative' , 'Unknown')  then 'IMP' 
		   else '' end as CPO_CARB_MECHANISM "CPO mechanism"



from denorm.laboratory_dd_table_cre

	having CPO_CARB_MECHANISM not in ('') or CRE_CARB_PRODUCE_MECHANISM not in ('')/*don't need missing values, only counting where we identified 1 or more mechanism(s)*/
;
quit;

proc sql;
create table labs_clean_2 as
select distinct

	case_ID,
	CRE_CARB_ORGANISM,
	CRE_CARB_PRODUCE_MECHANISM,
	CPO_CARB_MECHANISM


from CPO_mechext
;
quit;

/*Now join them all with table 1 from the denormalized, confirmed, deduplicated, and reported to CDC count (table 4 (final))*/
proc sql;
create table CRE_mech as
select 

	a.*,
	b.CRE_CARB_ORGANISM,
	b.CRE_CARB_PRODUCE_MECHANISM,
	b.CPO_CARB_MECHANISM

from HAI_updated as a 
	left join labs_clean_2 as b on a.case_ID = b.case_ID

	where a.type in ("CRE" , "CPO")
;

quit;

proc print data=CRE_mech; where CPO_CARB_MECHANISM in ('OXA-23');run;


proc sql;
create table cre_cpo_dupes as
select

	case_id,
	type, 
	owning_jd,
	CRE_CARB_PRODUCE_MECHANISM,
	CPO_CARB_MECHANISM,
			BIRTH_DATE, EVENT_DATE

from CRE_mech
	where type in ('CRE', 'CPO') and year in (2023, 2024, 2025)
		order by EVENT_DATE desc;
quit;

proc print data=cre_cpo_dupes (obs=100) noobs; where type in ('CRE'); run;


/*fin*/

proc sql;
create table MDRO_display as
select 

case when TYPE in ('STRA') then 'GAS' 
		else TYPE end as type_new "MDRO",

	sum (case when year in (2023) then 1 else 0 end) as cases_23 "2023",
	sum (case when year in (2024) then 1 else 0 end) as cases_24 "2024",
	sum (case when year in (2025) then 1 else 0 end) as cases_25 "2025"

from HAI_updated
	where type in ("CPO","CRE","CAURIS","STRA")
	group by TYPE 
;

create table cpo_mech_display as
select

	CPO_CARB_MECHANISM "CPO Mechanism",
	sum (case when year in (2023) then 1 else 0 end) as cpo_mech_23 "2023",
	sum (case when year in (2024) then 1 else 0 end) as cpo_mech_24 "2024",
	sum (case when year in (2025) then 1 else 0 end) as cpo_mech_25 "2025"

from CRE_mech
	where type in ("CPO")
	group by CPO_CARB_MECHANISM
	having CPO_CARB_MECHANISM not in ('')
;
create table cre_mech_display as
select

	CRE_CARB_PRODUCE_MECHANISM "CRE Mechanism",
	sum (case when year in (2023) then 1 else 0 end) as cre_mech_23 "2023",
	sum (case when year in (2024) then 1 else 0 end) as cre_mech_24 "2024",
	sum (case when year in (2025) then 1 else 0 end) as cre_mech_25 "2025"

from CRE_mech
	where type in ("CRE")
	group by CRE_CARB_PRODUCE_MECHANISM
		having CRE_CARB_PRODUCE_MECHANISM not in ('')
;
quit;

/*Combine CRE/CPO mechanism counts*/
proc sql;
create table cre_cpo_combine as
select

	a.CPO_CARB_MECHANISM "CRE/CPO Mechanism", 
	case when cre_mech_23 not in (.) then a.cpo_mech_23 + b.cre_mech_23 else a.cpo_mech_23 end as tot_mech_23 "2023",
	case when cre_mech_24 not in (.) then a.cpo_mech_24 + b.cre_mech_24 else a.cpo_mech_24 end as tot_mech_24 "2024",
	case when cre_mech_25 not in (.) then a.cpo_mech_25 + b.cre_mech_25 else a.cpo_mech_25 end as tot_mech_25 "2025"


from cpo_mech_display a left join CRE_mech_display b
	on a.CPO_CARB_MECHANISM = b.CRE_CARB_PRODUCE_MECHANISM
;

quit;

dm 'odsresults; clear';
proc print data=cre_cpo_combine label noobs;run;

proc print data= MDRO_display noobs label;run;	

	

/*Quick look at events with multiple CPO/CRE mechanisms*/
proc sql;
create table dupes_mech as
select
	case_id,
	type,
	CPO_CARB_MECHANISM,
	count(*) as dupes_mech,
	year

from CRE_mech

	group by case_id

	having COUNT(*) > 1;
quit;

proc print data=dupes_mech;run;
