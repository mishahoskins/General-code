
/*
 *------------------------------------------------------------------------------
 * Program Name:  MDRO_dates
 * Author:        Mikhail Hoskins
 * Date Created:  10/01/2025
 * Date Modified: 
 * Description:   The purpose of this code is to extract all MDRO events from the denormalized tables and associated dates of interaction.
 *				  Dates of interaction include: create date, report date, specimen dates, and other assigment dates. 
 *
 * Inputs:       laboratory_dd_table_cre : Z:\YYYYMMDD
 * Output:       MDRO_dates_&sysdate..xlsx <-- a line list of all MDRO within specified date range to review dates. 
 * Notes:        
 *				
 *				 Annotations are between /* to help guide. We use an ETL process: extract raw data, transform (kinda) into what we want, 
 * 				 load a dataset to use in future analysis. 
 *				 
 *
 *------------------------------------------------------------------------------
 */


/*Set your pathway. Must have Z drive (or however you are mapped to denormalized tables) access.*/
libname denorm 'Z:\20250901'; /*Select the file name you want from the Z drive. Format is YYYYMMDD. Tables are created monthly*/
/*Set your date range of interest in the format specified.*/
%let start_dte = 01Jan25; /*Set your start date for range of values DDMMYY*/
%let end_dte = 01Sep25; /*Set your end date for range of values DDMMMYY*/



						/*I.		EXTRACT			*/

/*Modified dashboard data set creation. In this case we want everything we're investigating that is confirmed/probable. Reporting to CDC or not included.*/
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
			and s.type in ("CAURIS", "STRA")
			/*and s.REPORT_TO_CDC = 'Yes' /*right now we want ALL cases, even those not confirmed/sent to CDC yet*/
;

quit;

/*Get CRE/CPO*/
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
/*Combine to one dataset*/
data MDRO_raw;
set CASE_COMBO CASE_COMBO_2;
	where DATE_FOR_REPORTING GE ("&start_dte"d);
run;

proc contents data=MDRO_raw order=varnum;run;

proc sql;
create table MDRO_dates as
select

	CASE_ID,
	TYPE,

	/*Dates*/
		CREATE_DT,
		DATE_FOR_REPORTING,
		MMWR_DATE_BASIS,
		MMWR_WEEK,
		MMWR_YEAR,
		LAST_CDC_EVENT_DATE_TRANSMITTED,
		EVENT_DATE_NEXT_SEND,
		LHD_DIAGNOSIS_DATE,
		SYMPTOM_ONSET_DATE,
		DEDUPLICATION_DATE,
		CDC_BASE_DATE,
		DATE_TRANSMITTED_CDC,
		EFFECTIVE_DATE,
		RPTI_SOURCE_DT_SUBMITTED,
		DISEASE_ONSET_QUALIFIER /*What date was used for classification*/

from MDRO_raw
	order by CASE_ID , TYPE
;
quit;

proc print data=MDRO_dates (obs=100) noobs;run;



title; footnote;
/*Set your output pathway here*/
ods excel file="T:\HAI\Code library\Epi curve example\outputs\MDRO Date_Tables_&sysdate..xlsx";*<----- Named a generic overwriteable name so we can continue to reproduce and autopopulate a template;
ods excel options (sheet_interval = "none" sheet_name = "date table" embedded_titles='Yes');
/*transposed tables-demographics*/
proc print data=MDRO_dates noobs label;run;


ods excel close;
