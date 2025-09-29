
/*
 *------------------------------------------------------------------------------
 * Program Name:  GAS_Outbreaks_18_24
 * Author:        Mikhail Hoskins
 * Date Created:  09/23/2025
 * Date Modified: 
 * Description:   We want to evaluate GAS over the last decade + in NC. Recent study showed an increase year over year, can we replicate for NC.
 *				  (https://jamanetwork.com/journals/jamanetworkopen/fullarticle/2831512#)
 *
 * Inputs:       GAS report from NCEDSS for 2018-2024 n=67 outbreaks. 
 * Output:       .
 * Notes:        Program pulls GAS Outbreaks. 
 *				 Annotations are between /* to help guide.
 *					
 *				Definitions: "LTCF Associated" = Primary setting for infection indicates a Long term care facility [Sept 2025 count].
 *												 (Nursing Home [422], Skilled Nursing, Assisted Living, or Adult Care Home [570])
 *------------------------------------------------------------------------------
 */


/*Step 1: set your pathway. Must have Z drive (or however you are mapped to denormalized tables) access.*/
libname denorm 'Z:\20250301'; /*Select the file name you want from the Z drive. Format is YYYYMMDD. Tables are created monthly*/
libname analysis 'T:\HAI\Code library\Epi curve example\ncedss extracts\Datasets';/*Path to export your dataset so we don't have to import denormalized tables every time*/
/*Step 1a: set your date range in the format specified.*/
%let start_dte = 01JAN18; /*Set your start date for range of values DDMMYY*/
%let end_dte = 31DEC24; /*Set your end date for range of values DDMMMYY*/

	%let directory = T:\HAI\Code library\Epi curve example;
	%put &directory;

dm 'odsresults; clear';


/*Manual import of NCEDSS report: name, gas_outbreaks_2018_2024.csv*/
/*import outbreak report*/
proc import datafile="&directory.\ncedss extracts\gas_outbreaks_2018_2024.xlsx"
	out=GAS_outbreaks_18_24
	dbms=xlsx replace;
	getnames=yes;

run;


proc contents data=GAS_outbreaks_18_24 order=varnum;run;

proc freq data=GAS_outbreaks_18_24; tables Date_of_illness_onset_for_the_fi /norow nocol nopercent nocum;run;

proc sql;
create table year_breakdown as
select

	intnx("year", (Create_Date), 0, "end") as rep_yr "Report Year" format=year4.,
	intnx("month", (Create_Date), 0, "end") as rep_mo "Report Month" format=monname3.,
	Create_Date,
	Disease, 
	Date_of_illness_onset_for_the_fi as ill_onset_first,
	Date_of_illness_onset_for_last_c as ill_onset_last,
	(Date_of_illness_onset_for_last_c) - (Date_of_illness_onset_for_the_fi) as length_otbk "Approx length of outbreak",
	Setting__primary_ as setting,
	Primary_setting_or_facility_name as facility_name,

	/*clinical, demographic*/
	Total_number_of_cases, Total_Died, Total_Visited_ER, Total_Hospitalized, Total_number_people_tested, Total_number_of_people_positive, Residents_Students_Patrons_In_fa, Faculty_Staff_Employees_In_facil, Total_In_facility___setting,
	Females, Male, Gender_Unknown

from GAS_outbreaks_18_24
	where Setting__primary_ in ('Long term care facility (Nursing Home, Skilled Nursing, Assisted Living, Adult Care Home)')
;

create table year_case as
select

	rep_yr,
	count (Disease) as events_yr "LTCF associated outbreak count in year",
	sum (case when Total_number_of_cases not in (.) then Total_number_of_cases else 0 end) as case_yr "LTCF outbreak associated cases in year",
	sum (case when Total_Hospitalized not in (.) then Total_Hospitalized else 0 end) as hosp_yr "LTCF outbreak associated hospitalizations in year",
	sum (case when Total_Died not in (.) then Total_Died else 0 end) as died_yr "LTCF outbreak associated deaths in year",

		calculated died_yr / calculated case_yr as cfr_GAS "LTCF associated CFR in year" format percent10.1,

	avg(length_otbk) as avg_otbrklngth "Avg. approx. outbreak duration (days)" format 10.0


from year_breakdown
	group by rep_yr
;
quit;

dm 'odsresults; clear';

proc print data=year_case noobs label; run;

proc print data=year_breakdown; var rep_mo;run;















