
/*
 *------------------------------------------------------------------------------
 * Program Name:  GAS_Prep_20250514
 * Author:        Mikhail Hoskins
 * Date Created:  05/14/2025
 * Date Modified: 05/14/2025
 * Description:   We want to evaluate GAS over the last decade + in NC. Recent study showed an increase year over year, can we replicate for NC.
 *				  (https://jamanetwork.com/journals/jamanetworkopen/fullarticle/2831512#)
 *
 * Inputs:       case.sas7bdat , case_phi.sas7bdat , Admin_question_package_addl.sas7bdat : Z:\YYYYMMDD , risk factors from NCEDSS
 * Output:       .
 * Notes:        Program pulls GAS. 
 *				 Annotations are between /* to help guide. If the code doesn't work or numbers don't align, check here: 
 *				 https://github.com/NC-DPH/Communicable-Disease-Dashboards/blob/main/NCD3v2%20In%20Progress.sas
 *					Split prior code into a "prep" step and then the analysis step in the original program. 
 *
 *------------------------------------------------------------------------------
 */


/*Step 1: set your pathway. Must have Z drive (or however you are mapped to denormalized tables) access.*/
libname denorm 'Z:\20250301'; /*Select the file name you want from the Z drive. Format is YYYYMMDD. Tables are created monthly*/
libname analysis 'T:\HAI\Code library\Epi curve example\ncedss extracts\Datasets';/*Path to export your dataset so we don't have to import denormalized tables every time*/
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
	and s.type in ("STRA") 
	and s.REPORT_TO_CDC = 'Yes';

quit;


/*Step 3: Table 2: Confine to certain key variables. You can add and subtract variables here to fit your needs if necessary*/
proc sql;
create table GAS_updated as
select 
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

		/*don't delete this section, it's a logic path for how the state creates an event date based on submission, lab, and symptom dates*/
	case 
		when SYMPTOM_ONSET_DATE ne . then SYMPTOM_ONSET_DATE
	    when (SYMPTOM_ONSET_DATE = . ) and  RPTI_SOURCE_DT_SUBMITTED  ne . then RPTI_SOURCE_DT_SUBMITTED
	    else datepart(CREATE_DT)
	    end as EVENT_DATE_2 format=DATE9., 

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

from CASE_COMBO
where calculated EVENT_DATE >= "&start_dte."d and calculated EVENT_DATE <= "&end_dte."d
	and STATUS = 'Closed'
	/*and STATE in ('NC' ' ')*/
order by TYPE_DESC, YEAR, OWNING_JD;
quit;

















/*Step 4: Now to get LTCF, need NCEDSS risk history package*/
/*import risk report*/
proc import datafile='T:\HAI\Code library\Epi curve example\ncedss extracts\GAS_risk history_2012_2024.xlsx'
	out=risk_import
	dbms=xlsx replace;
	getnames=yes;
run;



/*Clear results from prior code*/
dm 'odsresults; clear';
proc contents data=risk_import order=varnum;run;
proc print data=risk_import; var HCE_FACILITY_ZIP_0 HCE_FACILITY_ZIP_1 HCE_FACILITY_ZIP_2;run;

/*New version using like % % to get strings of LTCF qualifiers: this is what we'll join with prior tables so name = table 3*/
proc sql;
create table ltcf_risk_2 as
select

	CASEID as case_id,
	LIVE_IN_HIGH_RISK_SETTING_TIME13,
	LIVE_IN_HIGH_RISK_SETTING_TIMEFR,
	EXPOSURE_SETTING_NOTES as setting_notes,
	coalesce (HCE_FACILITY_ZIP_0, HCE_FACILITY_ZIP_1, HCE_FACILITY_ZIP_2) as fac_zip,
	EXPOSURE_SETTING_LOCATION_NC_COU as exp_county,
	case when (LIVE_IN_HIGH_RISK_SETTING_TIMEFR in ('OTHER')) 
		 and (LIVE_IN_HIGH_RISK_SETTING_TIME13 like '%Long%' or 
			  LIVE_IN_HIGH_RISK_SETTING_TIME13 like '%LTC%' or 
			  LIVE_IN_HIGH_RISK_SETTING_TIME13 like '%ALF%' or 
			  LIVE_IN_HIGH_RISK_SETTING_TIME13 like '%SNF%' or
			  LIVE_IN_HIGH_RISK_SETTING_TIME13 like '%Long%' or 
			  LIVE_IN_HIGH_RISK_SETTING_TIME13 like '%Assisted%' or 
			  LIVE_IN_HIGH_RISK_SETTING_TIME13 like '%Skilled%' or 
			  LIVE_IN_HIGH_RISK_SETTING_TIME13 like '%Nsg F%' or 
			  LIVE_IN_HIGH_RISK_SETTING_TIME13 like '%Senior Living%' or 
			  LIVE_IN_HIGH_RISK_SETTING_TIME13 like '%LTCF%' or
			  LIVE_IN_HIGH_RISK_SETTING_TIME13 like '%Adult Care%' or 
			  LIVE_IN_HIGH_RISK_SETTING_TIME13 like '%Alzheimers%' or 
			  LIVE_IN_HIGH_RISK_SETTING_TIME13 like '%Autumn Care%' or 
			  LIVE_IN_HIGH_RISK_SETTING_TIME13 like '%Group Home%' or 
			  LIVE_IN_HIGH_RISK_SETTING_TIME13 like '%Memory%' or 
			  LIVE_IN_HIGH_RISK_SETTING_TIME13 like '%Nursing Home%' or 
/*different spelling/capitalization*/
			  LIVE_IN_HIGH_RISK_SETTING_TIME13 like '%assisted%' or 
			  LIVE_IN_HIGH_RISK_SETTING_TIME13 like '%skilled nursing%' or 
			  LIVE_IN_HIGH_RISK_SETTING_TIME13 like '%skilled%' or 
			  LIVE_IN_HIGH_RISK_SETTING_TIME13 like '%senior%' or 
			  LIVE_IN_HIGH_RISK_SETTING_TIME13 like '%memory care%' or 
			  LIVE_IN_HIGH_RISK_SETTING_TIME13 like '%long term%' or 
			  LIVE_IN_HIGH_RISK_SETTING_TIME13 like '%long%' or
			  LIVE_IN_HIGH_RISK_SETTING_TIME13 like '%nursing home%' or

			  LIVE_IN_HIGH_RISK_SETTING_TIME13 in ('group home') or 
			  LIVE_IN_HIGH_RISK_SETTING_TIME13 like '%dementia%' or 
			  LIVE_IN_HIGH_RISK_SETTING_TIME13 like '%Rehab%' or 
			  LIVE_IN_HIGH_RISK_SETTING_TIME13 like '%Rehabilitation%')  

		then 1 else 0 end as LTCF

from risk_import
;
quit;

proc print data=ltcf_risk_2 noobs; where ltcf in (1);run;


proc sql;
create table testing as
select 
		exp_county,
		count(exp_county) as count_exp

from ltcf_risk_2 
where LTCF in (1) 
	group by exp_county having count_exp > 0
	order by count_exp desc
		
	
;
quit;

proc print data=testing noobs;run;


/*Now join them all with table 1 from the denormalized, confirmed, deduplicated, and reported to CDC count (table 4 (final))*/
proc sql;
/*patient outcome, surgical experience, LTCF residency, IV drug use variables add here*/
create table GAS_updated_2 as
select 

	a.*,
	b.PAT_OCM, /*Patient outcome*/
	c.HCE, /*Surgical experience*/
	d.TF_USED_INJECTION_RXS, /*Injection drug use*/
	e.LTCF, /*Long term care*/
	e.LIVE_IN_HIGH_RISK_SETTING_TIME13 as high_risk_label, /*high risk label*/
	e.LIVE_IN_HIGH_RISK_SETTING_TIMEFR as high_risk_setting, /*high risk congregate setting -- also relevant*/
	e.setting_notes,
	e.fac_zip,
	e.exp_county

from GAS_updated as a 

	left join denorm.clinic_outcomes_cd as b on a.case_id=b.case_id
	left join denorm.risk_health_care_exp_cd as c on a.case_id=c.case_id
	left join denorm.risk_misc_one_time_cd as d on a.case_id=d.case_id
	left join ltcf_risk_2 as e on a.case_id = e.case_id

;
quit;




proc sql;
create table testing as
select 
		year,
		exp_county,
		count(exp_county) as count_exp

from GAS_updated_2 
where LTCF in (1) 
	group by exp_county , year
		having count_exp > 0 
	order by year , count_exp desc
		
	
;
quit;

proc print data=testing noobs;run;




/*Missing values by variable*/


/*Save dataset so we don't have run import step every time (very useful on VPN)*/
data analysis.GAS_2012_2024;
set GAS_updated_2;
run;


/*Long term car facility set*/

proc sql;
create table LTCF_analysis as
select

	case_id,
	LTCF,
	high_risk_label,
	OWNING_JD as reporting_county,
	PAT_OCM as pt_outcome


from GAS_updated_2
	having LTCF in (1)
;
quit;

proc print data=LTCF_analysis noobs;run;
