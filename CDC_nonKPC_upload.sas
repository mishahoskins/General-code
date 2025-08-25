
/*
 *------------------------------------------------------------------------------
 * Program Name:  CDC_nonKPC_RedCap_20250825 
 * Author:        Mikhail Hoskins
 * Date Created:  08/25/2025
 * Date Modified: .
 * Description:   CPO count by mechanism data pull from monthly denormalized tables. Easy to run in office, can take longer
				  on VPN. 
 *
 * Inputs:       laboratory_dd_table_cre : Z:\YYYYMMDD
 * Output:       CDC_nonKPC_RedCap_20250825.xlsx
 * Notes:        Program pulls CPO HAIs. ***CPOs will be updated in the denormalized tables to 
 *				 reflect CPO rule change . 
 *				 Annotations are between /* to help guide. This is one clean ahh code fr.  
 *				 
 *
 *------------------------------------------------------------------------------
 */


/*Step 1: set your pathway. Must have Z drive (or however you are mapped to denormalized tables) access.*/
libname denorm 'Z:\20250801'; /*Select the file name you want from the Z drive. Format is YYYYMMDD. Tables are created monthly*/
/*Step 1a: set your date range in the format specified.*/
%let start_dte = 01Apr25; /*Set your start date for range of values DDMMYY*/
%let end_dte = 25Aug25; /*Set your end date for range of values DDMMMYY*/

dm 'odsresults; clear';


/*Extract CPO mechanisms, we only want non-KPC so we'll drop KPC*/
proc sql;
create table CPO_mechext as
select

	case_ID as Event_ID "NCEDSS Event ID",
/*Take all CPOs and search for MECHANISMS in the lab results where the result is confirmed*/
	case  when product in ("CPO") and TEST like '%KPC%' and result not in ('Not Detected' , 'Not detected', 'Negative' , 'Unknown') then 'KPC'
		  when product in ("CPO") and  TEST like '%NDM%' and result not in ('Not Detected' , 'Not detected', 'Negative' , 'Unknown')  then 'NDM'
		  when product in ("CPO") and  TEST like '%OXA-48%' and result not in ('Not Detected' , 'Not detected', 'Negative' , 'Unknown')  then 'OXA-48' 
		  when product in ("CPO") and  TEST like '%OXA-23%' and result not in ('Not Detected' , 'Not detected', 'Negative' , 'Unknown')  then 'OXA-23' 
		  when product in ("CPO") and  TEST like '%OTHER%' and result not in ('Not Detected' , 'Not detected', 'Negative' , 'Unknown')  then 'Other' 
		  when product in ("CPO") and  TEST like '%VIM%' and result not in ('Not Detected' , 'Not detected', 'Negative' , 'Unknown')  then 'VIM' 
		   else '' end as CPO_CARB_MECHANISM "CPO mechanism",

	CRE_CARB_ORGANISM as organism "Organism identified",
	SPECIMEN_DT as spec_date "Specimen date" format date9.,
	HCE "Healthcare experience, setting type",


/*Ok for zip code, it gets hairy: first lets combine all of our addresses into one*/
	case when ORDER_FACILITY not in ('Other Hospital/Health Facility||' , '') then ORDER_FACILITY else '' end as order_facility_1, /*This takes facility names where we have them and drops other text to missing*/
	coalesce(calculated order_facility_1 , ORDER_FAC_OTHER) as fac_final, /*Combine to a single facility column*/

/*Now we're going to use a prx match to find anything that follows two capital letters and a comma, for example: NC, (this is almost always a zip in an address)*/
	case when prxmatch('/, [A-Z]{2}, *\d{5}/', calculated fac_final) > 0 then prxchange('s/.*?, [A-Z]{2}, *(\d{5}).*/\1/', 1, calculated fac_final) /*At the end here we prx change it to pull out just the 5 number zip*/
		else ''
	end as zip_code "Ordering facility zip", /*and we leave it blank if the pattern is unmatched, and name it zip code*/

/*For ease of reading, we'll pull in the facility name for the missing values so we can manually find them on the front end*/
	case when calculated zip_code in ('') then calculated fac_final else '' end as facility "No zip; facility name" 


from denorm.laboratory_dd_table_cre
/*Confine to CPO, since our start date, and not missing or KPC*/
	where product in ('CPO') and SPECIMEN_DT GE ("&start_dte"d)
	having CPO_CARB_MECHANISM not in ('KPC' , '')
	order by case_ID	
;
/*Drop the columns we created that we don't actually care about (new facility name and facility final*/
alter table CPO_mechext drop order_facility_1 , fac_final
;

quit;

/*Last thing, dedupe on event ID, mechanism, and organism. If all three line up then no need to have multiple rows*/
proc sort data=CPO_mechext out=CPO_RedCap_raw nodupkey;
	by Event_ID CPO_CARB_MECHANISM organism;
run;


/*Output so team can review in a nice clean excel sheet*/
title; footnote;
/*Set your output pathway here*/
ods excel file="T:\HAI\Code library\Epi curve example\analysis\CPO_CDCRedCap Upload_&sysdate..xlsx";

ods excel options (sheet_interval = "now" sheet_name = "CPO: &start_dte" embedded_titles='Yes');
proc print data=CPO_RedCap_raw noobs label;run;

ods excel close;
