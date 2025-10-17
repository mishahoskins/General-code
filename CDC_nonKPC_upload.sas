
/*
 *------------------------------------------------------------------------------
 * Program Name:  CDC_nonKPC_upload 
 * Author:        Mikhail Hoskins
 * Date Created:  08/25/2025
 * Date Modified: .
 * Description:   CPO count by mechanism data pull from monthly denormalized tables. Easy to run in office, can take longer
				  on VPN. 
 *
 * Inputs:       laboratory_dd_table_cre : Z:\YYYYMMDD
 * Output:       CDC_nonKPC_RedCap_DATE.xlsx <-- a line list of all CPO within specified date range to review and submit to CDC. 
 * Notes:        Program pulls CPO HAIs. ***CPOs will be updated in the denormalized tables to 
 *				 reflect CPO rule change . 
 *				 Annotations are between /* to help guide.   
 *				 
 *
 *------------------------------------------------------------------------------
 */


/*Set your pathway. Must have Z drive (or however you are mapped to denormalized tables) access.*/
libname denorm 'Z:\20251001'; /*Select the file name you want from the Z drive. Format is YYYYMMDD. Tables are created monthly*/
/*Set your date range in the format specified.*/
%let start_dte = 01APR25; /*Set your start date for range of values DDMMYY*/
%let end_dte = 30SEP25; /*Set your end date for range of values DDMMMYY*/

/*Now we'll set our case manager names: update as needed to the number/names of those responding to NCEDSS entries AS THEIR NAMES APPEAR IN NCEDSS.*/
/*Misspelled names or different capitalizations my throw off numbers by 1 or 2. Make sure names are correct in NCEDSS*/

		/*Removed names in Git so it's not immedietly obvious*/
%let name1 =
%let name2 =
%let name3 =
%let name4 =
%let name5 =

/*Worth checking the log to make sure they're displaying properly*/
	%put &name1;
	%put &name2;
	%put &name3;
	%put &name4;
	%put &name5;

/*clear all your other terrible results*/
dm 'odsresults; clear';

/*Extract CPO mechanisms, we only want non-KPC so we'll drop KPC later*/
proc sql;
create table CPO_mechext as
select

	case_ID as Event_ID "NCEDSS Event ID",
	product,
/*Take all CPOs and search for MECHANISMS in the lab results where the result is confirmed*/
	case  when product in ("CPO", "CRE") and TEST like '%KPC%' and result not in ('Not Detected' , 'Not detected', 'Negative' , 'Unknown') then 'KPC'
		  when product in ("CPO", "CRE") and  TEST like '%NDM%' and result not in ('Not Detected' , 'Not detected', 'Negative' , 'Unknown')  then 'NDM'
		  when product in ("CPO", "CRE") and  TEST like '%OXA-48%' and result not in ('Not Detected' , 'Not detected', 'Negative' , 'Unknown')  then 'OXA-48' 
		  when product in ("CPO", "CRE") and  TEST like '%OXA-23%' and result not in ('Not Detected' , 'Not detected', 'Negative' , 'Unknown')  then 'OXA-23'
		  when product in ("CPO", "CRE") and  TEST like '%OXA-24%' and result not in ('Not Detected' , 'Not detected', 'Negative' , 'Unknown')  then 'OXA-24'  
		  when product in ("CPO", "CRE") and  TEST like '%OTHER%' and result not in ('Not Detected' , 'Not detected', 'Negative' , 'Unknown')  then 'Other' 
		  when product in ("CPO", "CRE") and  TEST like '%VIM%' and result not in ('Not Detected' , 'Not detected', 'Negative' , 'Unknown')  then 'VIM' 
		  when product in ("CPO", "CRE") and  TEST like '%IMP%' and result not in ('Not Detected' , 'Not detected', 'Negative' , 'Unknown')  then 'IMP' 
		   else '' end as CPO_CARB_MECHANISM "CPO mechanism",

	CRE_CARB_ORGANISM as organism "Organism identified",
	max(SPECIMEN_DT) as spec_date "Most Recent Specimen date" format date9.,
	HCE "Healthcare experience, setting type",

/*Ok for zip code, it gets hairy: first lets combine all of our addresses into one*/
	case when ORDER_FACILITY not in ('Other Hospital/Health Facility||' , '') then ORDER_FACILITY else '' end as order_facility_1, /*This takes facility names where we have them and drops other text to missing*/
	coalesce(calculated order_facility_1 , ORDER_FAC_OTHER) as fac_final, /*Combine to a single facility column*/

/*Now we're going to use a regular expression-prx match to find anything that follows two capital letters and a comma, for example: NC, (this is almost always a zip in an address)*/
	case when prxmatch('/, [A-Z]{2}, *\d{5}/', calculated fac_final) > 0 then prxchange('s/.*?, [A-Z]{2}, *(\d{5}).*/\1/', 1, calculated fac_final) /*At the end here we prx change it to pull out just the 5 number zip*/
		else ''
	end as zip_code "Ordering facility zip", /*and we leave it blank if the pattern is unmatched, and name it zip code*/

/*For ease of reading, we'll pull in the facility name for the missing values so we can manually find them on the front end*/
	case when calculated zip_code in ('') then calculated fac_final else '' end as facility "No zip; facility name"


from denorm.laboratory_dd_table_cre
/*Confine to CPO, since our start date, and not missing or KPC*/
	where product in ('CPO','CRE') and SPECIMEN_DT GE ("&start_dte"d)
	group by Event_ID
	having CPO_CARB_MECHANISM not in ('') /*Add or remove mechanisms here to refine*/
	order by case_ID	
;
/*Drop the columns we created that we don't actually care about (new facility name and facility final*/
alter table CPO_mechext drop order_facility_1 , fac_final
;
quit;


/*Now we need to find who each case is assigned to at the state*/
proc sql;
create table case_manager_CPO as
select 

	case_ID,
	NAME_OF_CASE_MANAGER,
	NAME_OF_CASE_MANAGER as case_manag,
	case when NAME_OF_CASE_MANAGER in ("&name1.", "&name2.", "&name3.", "&name4.", "&name5.") then 1 else 0 end as dhhs_tag,
	case when NAME_OF_CASE_MANAGER in ("&name3.", "&name4.") then 'Yes' else 'No' end as ELC "ELC Core Program H",
	case when NAME_OF_CASE_MANAGER in ("&name1.", "&name2.", "&name5.") then 'Yes' else 'No' end as SHARP_I_II	"SHARP I or SHARP II",
	CODE

from denorm.admin_trail
	
	where ASSIGNED_TO_DT GE ("01jan2025"d) /*Pulling a smaller subset from denorm tables for time*/
		and CODE in ("CPO" , "CRE") /*Keep only CPO/CRE (should only be CPO but just in case)*/
	having dhhs_tag in (1)/*drop if not NC DPH employee*/ 
	order by case_ID desc 
		;
quit;

proc sql;
create table case_manager_merge as
select 

	a.*,
	b.case_manag,
	b.ELC,
	b.SHARP_I_II


from CPO_mechext a left join case_manager_CPO b 
	on a.Event_ID = b.CASE_ID
	;


quit;
/*Last thing, dedupe on event ID, mechanism, and organism. If all three line up then no need to have multiple rows*/
proc sort data=case_manager_merge out=CPO_RedCap_raw nodupkey;
	by Event_ID CPO_CARB_MECHANISM organism;
	
run;
/*Proc sort messes up the ordering because we're not sorting/deduplicating by date anywhere. Also confine to non-KPC here if necessary*/
proc sql;
create table final_CRE_upload as
select * from CPO_RedCap_raw
	having CPO_CARB_MECHANISM not in ('KPC') /**/
	order by spec_date asc;
quit;

/*Output so team can review in a nice clean excel sheet*/
title; footnote;
/*Set your output pathway here*/
*ods excel file="T:\HAI\Code library\Epi curve example\analysis\CPO_ALL_&sysdate..xlsx"; /*<-- use this name if you include KPC*/
ods excel file="T:\HAI\Code library\Epi curve example\analysis\CDC Reporting\CPO_CDCRedCap Upload_&sysdate..xlsx";
ods excel options (sheet_interval = "now" sheet_name = "CPO: &start_dte" embedded_titles='Yes');

	proc print data=final_CRE_upload noobs label;run;

ods excel close;


proc print data=final_CRE_upload; where case_manag in ('');run;

