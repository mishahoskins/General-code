
/*
 *------------------------------------------------------------------------------
 * Program Name:  GAS_analysis_20250409 
 * Author:        Mikhail Hoskins
 * Date Created:  04/09/2025
 * Date Modified: 09/16/2025
 * Description:   We want to evaluate GAS over the last decade + in NC. Recent study showed an increase year over year, can we replicate for NC.
 *				  (https://jamanetwork.com/journals/jamanetworkopen/fullarticle/2831512#)
 *
 * Inputs:       case.sas7bdat , case_phi.sas7bdat , Admin_question_package_addl.sas7bdat : Z:\YYYYMMDD
 * Output:       .
 * Notes:        Program pulls GAS. 
 *				 Annotations are between /* to help guide. If the code doesn't work or numbers don't align, check here: 
 *				 https://github.com/NC-DPH/Communicable-Disease-Dashboards/blob/main/NCD3v2%20In%20Progress.sas
 *					Added LTCF 5/14 linear, stat sig using C-A for prop from 2012-2024. Interesting stuff.
 *
 *------------------------------------------------------------------------------
 */


/*Step 1: set your pathway.*/
libname denorm 'Z:\20250301'; /*Select the file name you want from the Z drive. Format is YYYYMMDD. Tables are created monthly*/
libname analysis 'T:\HAI\Code library\Epi curve example\ncedss extracts\Datasets';/*Path to export your dataset so we don't have to import denormalized tables every time*/
%let start_dte = 01JAN12; /*Set your start date for range of values DDMMYY*/
%let end_dte = 31DEC24; /*Set your end date for range of values DDMMMYY*/


/*------------------------------------------------------------------BEGIN ANALYSIS HERE UNLESS CHANGING DENORMALIZED INPUTS------------------------------------------------------------------*/

/*Step 2: Import dataset unless you have made changes prior*/

data GAS_updated_2;
set analysis.GAS_2012_2024;
run;

/*Begin cleaning and analysis*/

/*Step 3: General trends*/
proc sql;
create table GAS_trend as 
select

	YEAR as report_yr "Report Year",
	/*intnx("month", (MMWR_DATE_BASIS), 0, "end") as testreportqtr "Quarter Ending Date" format=date11., */

	sum (case when TYPE_DESC in ('Streptococcal invasive infection, Group A (61)') then 1 else 0 end) as GAS "Annual Count, GAS",
/*Clinical Outcome*/
	sum (case when PAT_OCM in ('Died') then 1 else 0 end) as GAS_died_y "Died",
/*Ethnicity*/
		sum (case when TYPE_DESC in ('Streptococcal invasive infection, Group A (61)') and HISPANIC in ('Yes') then 1 else 0 end) as 
			GAS_hisp "Annual Count, GAS Hispanic Eth.",
		sum (case when TYPE_DESC in ('Streptococcal invasive infection, Group A (61)') and HISPANIC in ('No') then 1 else 0 end) as 
			GAS_nonhisp "Annual Count, GAS Non-Hispanic Eth.",
/*Gender*/
		sum (case when TYPE_DESC in ('Streptococcal invasive infection, Group A (61)') and GENDER in ('Male') then 1 else 0 end) as 
			GAS_male "Annual Count, GAS Gender: Male",
		sum (case when TYPE_DESC in ('Streptococcal invasive infection, Group A (61)') and GENDER in ('Female') then 1 else 0 end) as 
			GAS_female "Annual Count, GAS Gender: Female",
/*Race*/
		sum (case when TYPE_DESC in ('Streptococcal invasive infection, Group A (61)') and RACE1 in ('White') then 1 else 0 end) as 
			GAS_white "Annual Count, GAS Race: White",
		sum (case when TYPE_DESC in ('Streptococcal invasive infection, Group A (61)') and RACE1 in ('Black or African American') then 1 else 0 end) 
			as GAS_blk "Annual Count, GAS Race: Black/A.A.",
		sum (case when TYPE_DESC in ('Streptococcal invasive infection, Group A (61)') and RACE1 in ('Asian') then 1 else 0 end) as 
			GAS_asian "Annual Count, GAS Race: Asian",
		sum (case when TYPE_DESC in ('Streptococcal invasive infection, Group A (61)') and RACE1 in ('American Indian Alaskan Native') then 1 else 0 end) as 
			GAS_AIAN "Annual Count, GAS Race: A.I./A.N.",
		sum (case when TYPE_DESC in ('Streptococcal invasive infection, Group A (61)') and RACE1 in ('Other') then 1 else 0 end) as 
			GAS_other "Annual Count, GAS Race: Other",
/*Invasive procedure*/
		sum (case when HCE not in ('', 'No') then 1 else 0 end) as GAS_surg "Annual Count, GAS post invasive procedure",
/*Injection drug use*/
		sum (case when (TF_USED_INJECTION_RXS in ('Yes') and YEAR in (2018,2019, 2020, 2021, 2022, 2023, 2024)) then 1 else . end) as GAS_inj "Annual Count, GAS injection drug use",
/*At or above median age*/
		sum (case when AGE GE (55) and AGE not in (.) then 1 else 0 end) as GAS_age_med "Age Greater-Than-or-Equal-To Median Age of Infection (55)",
		/*and below*/
		sum (case when AGE LT (55) and AGE not in (.) then 1 else 0 end) as GAS_age_LOW "Age Less Than Median Age of Infection (55)",
/*LTCF*/
		sum (case when LTCF in (1) and LTCF not in (.) then 1 else 0 end) as GAS_ltcf "GAS in LTCF",
/*GAS not in LTCF (ie. possibly circulating in general population*/
		(calculated GAS - calculated GAS_ltcf) as GAS_nonLTCF "GAS not in LTCF",

			(calculated GAS_ltcf / calculated GAS) as pct_GAS_LTCF "Percent of GAS identified in LTCF" format percent10.2,

	/*IR: 2023 NC population constants by race
			Gender
			%let male_pop =5538969;
			%let female_pop =5296522;
			Race pop.
			%let white_pop = 7564526;
			%let blackaa_pop = 2392417;
			%let asian_pop = 399358;
			%let napi_pop = 16677; Native Hawaiian/Pacific Islander in CDC census
			%let other_race_pop = 289706; Two or more races in Census track data
			%let aian_pop = 172807;
			Hispanic
			%let hisp_yes = 1238421;
			%let hisp_no = 9597070;*/


	(calculated GAS / 10835491) * 100000 as GAS_IR "Annual Estimated GAS IR" format 10.2,
	(calculated GAS_nonLTCF / 10835491) * 100000 as GAS_nonLTCF_IR "Annual Estimated GAS IR not in LTCF" format 10.2,

		(calculated GAS_died_Y / 10835491) * 100000 as GAS_IR_mort "Annual Estimated GAS Mortality Rate**" format 10.2, /*Denominator = total population*/
		(calculated GAS_died_Y / calculated GAS) as GAS_IR_fat "Annual Estimated GAS Case Fatality Rate**" format percent10.2, /*Denominator = total GAS cases*/
		(calculated GAS_Hisp / 1238421) * 100000 as GAS_IR_hisp "Annual Estimated GAS IR Hispanic" format 10.2,
		(calculated GAS_nonhisp / 9597070) * 100000 as GAS_IR_nonhisp "Annual Estimated GAS IR Non-Hispanic" format 10.2,
		(calculated GAS_male / 5538969) * 100000 as GAS_IR_male "Annual Estimated GAS IR Male" format 10.2,
		(calculated GAS_female / 5296522) * 100000 as GAS_IR_female "Annual Estimated GAS IR Female" format 10.2,
		(calculated GAS_white / 7564526) * 100000 as GAS_IR_white "Annual Estimated GAS IR White" format 10.2,
		(calculated GAS_blk / 2392417) * 100000 as GAS_IR_blk "Annual Estimated GAS IR Black/A.A." format 10.2,
		(calculated GAS_asian / 399358) * 100000 as GAS_IR_asian "Annual Estimated GAS IR Asian**" format 10.2,
		(calculated GAS_AIAN / 172807) * 100000 as GAS_IR_AIAN "Annual Estimated GAS IR A.I./A.N.**" format 10.2,
		(calculated GAS_other / 289706) * 100000 as GAS_IR_other "Annual Estimated GAS IR Other Race**" format 10.2,
		(calculated GAS_surg / 10835491) * 100000 as GAS_IR_surg "Annual Estimated GAS IR Invasive Surgery**" format 10.2,
		(calculated GAS_inj / 82130) * 100000 as GAS_IR_inj "Annual Estimated GAS IR Injection Druge Use**" format 10.2, /*From T:\HAI\Code library\Epi curve example\analysis and paper: https://academic.oup.com/cid/article/76/1/96/6628702 2018 estimate*/
		(calculated GAS_age_med / 10835491) * 100000 as GAS_age_med_IR "Annual Estimated GAS IR Age Above Median" format 10.2, /*need appropriate denominator here*/
		(calculated GAS_age_LOW / 10835491) * 100000 as GAS_age_LOW_IR "Annual Estimated GAS IR Age Below Median" format 10.2 /*need appropriate denominator here*/


/** = Not linear*/

from GAS_updated_2
	group by report_yr
;
quit;

proc print data=GAS_trend noobs label; var report_yr GAS GAS_ltcf pct_GAS_LTCF;run;

/*Step 4: Binary 1/0 vars for analysis (just makes regression and C-A a little easier*/
data GAS_clean;
set GAS_updated_2;
/*Make all classifications binary with 0 = reference*/
/*Hispanic ethnicity groups*/
	hispanic_new=.;
		if HISPANIC in ('Yes') then hispanic_new = 1;
		if HISPANIC	in ('No') then hispanic_new = 0;
/*Gender groups*/
	gender_new=.;
		if GENDER in ('Male') then gender_new = 1;
		if GENDER in ('Female') then gender_new = 0;
/*Race groups*/
	white_binary=.;
		if RACE1 in ('White') then white_binary = 1;
		if RACE1 not in ('White', '') then white_binary = 0;

	black_binary=.;
		if RACE1 in ('Black or African American') then black_binary = 1;
		if RACE1 not in ('Black or African American', '') then black_binary = 0;

	asian_binary=.;
		if RACE1 in ('Asian') then asian_binary = 1;
		if RACE1 not in ('Asian', '') then asian_binary = 0;

	AIAN_binary=.;
		if RACE1 in ('American Indian Alaskan Native') then AIAN_binary = 1;
		if RACE1 not in ('American Indian Alaskan Native', '') then AIAN_binary = 0;

	other_binary=.;
		if RACE1 in ('Other') then other_binary = 1;
		if RACE1 not in ('Other', '') then other_binary = 0;
/*Median Age (55)*/

	age_med=.;
	if AGE GE (55) then age_med = 1;
	if (AGE LT (55)) or (AGE in (.)) then age_med = 0;

	age_low=.;
	if AGE LE (55) then age_low = 1;
	if (AGE GE (55)) or (AGE in (.)) then age_low = 0;

/*Pt. Outcome*/
	died=.;
	if PAT_OCM in ('Survived') then died = 0;
	if PAT_OCM in ('Died') then died = 1;

/*Invasive Proc.*/
	surg=.;
	if HCE in ('No') then surg = 0;
	if HCE in ('Surgery (besides oral surgery), obstetrical or invasive procedure') then surg = 1;

/*Injection drug use*/
	inj_drug=.;
	if TF_USED_INJECTION_RXS in ('No') then inj_drug = 0;
	if TF_USED_INJECTION_RXS in ('Yes') then inj_drug = 1; /*Dropped ALL missing and classified as "Unknown"*/

run;

/*Keep only variables we're interested in using for logistic reg*/
proc sql;
create table GAS_analysis_logit as
select

	case_id,
	case when type in ('STRA') then 1 else 0 end as event_GAS, died, age, age_med, age_low, LTCF, hispanic_new, RACE1, gender_new, surg, inj_drug

from GAS_clean
	order by case_id
;
quit;




/*Create a logistic reg. model univariate*/
proc logistic data=GAS_analysis_logit descending outmodel=GAS_model_univariate;

	class died (param=ref ref='0') race1 (param=ref ref='White');
	model died = LTCF  / expb;

run;
/* keep only p < 0.2*/ 

/*Create a logistic reg. model using key variables. Backwards elimination at p < 0.2*/
proc logistic data=GAS_analysis_logit descending outmodel=GAS_model_logit_final;

	class died (param=ref ref='0') race1 (param=ref ref='White');
	model died = LTCF hispanic_new gender_new  age / expb;

run;

proc print data=GAS_model_logit;run;














/*Export dataset*/
data analysis.GAS_clean_20250514;
	set GAS_clean;
run;

/*And as a CSV for MK in R*/
proc export data=GAS_trend 
dbms=csv
outfile="T:\HAI\Code library\Epi curve example\ncedss extracts\Datasets\gas_trends_&sysdate..csv"
replace;
run;



/*Trend tables, C-A analysis, and linear test output*/

title; footnote;
/*Set your output pathway here*/
ods excel file="T:\HAI\Code library\Epi curve example\analysis\GAS_analysis_tables_&sysdate..xlsx";

ods excel options (sheet_interval = "now" sheet_name = "case/ir tables" embedded_titles='Yes');
proc print data=GAS_trend noobs label;run;

ods excel options (sheet_interval = "now" sheet_name = "Cochran-Armitage " embedded_titles='Yes');

proc freq data=GAS_clean; 

	table   gender_new*YEAR hispanic_new*YEAR white_binary*YEAR black_binary*YEAR 
			age_med*YEAR age_low*YEAR ltcf*YEAR/ trend norow nocol nopercent scores=table
															    plots=freqplot(twoway=stacked); 
		
run; 
ods excel options (sheet_interval = "none" sheet_name = "linear test" embedded_titles='Yes');
proc reg data=GAS_trend;
	model GAS_inj = report_yr / noprint;
	plot GAS_inj*report_yr / ;
run;

ods excel options (sheet_interval = "none" sheet_name = "linear test" embedded_titles='Yes');
proc reg data=GAS_trend;
	model GAS_nonLTCF = report_yr / noprint;
	plot GAS_nonLTCF*report_yr / ;

	model GAS_died_y = report_yr / noprint;
	plot GAS_died_y*report_yr / ;

	model GAS_hisp = report_yr / noprint;
	plot GAS_hisp*report_yr / ;

	model GAS_nonhisp = report_yr / noprint;
	plot GAS_nonhisp*report_yr / ;

	model GAS_male = report_yr / noprint;
	plot GAS_male*report_yr / ;

	model GAS_female = report_yr / noprint;
	plot GAS_female*report_yr / ;

	model GAS_white = report_yr / noprint;
	plot GAS_white*report_yr / ;

	model GAS_blk = report_yr / noprint;
	plot GAS_blk*report_yr / ;

	model GAS_Asian = report_yr / noprint;
	plot GAS_Asian*report_yr / ;

	model GAS_AIAN = report_yr / noprint;
	plot GAS_AIAN*report_yr / ;

	model GAS_other = report_yr / noprint;
	plot GAS_other*report_yr / ;

	model GAS_surg = report_yr / noprint;
	plot GAS_surg*report_yr / ;

	model GAS_age_med = report_yr / noprint;
	plot GAS_age_med*report_yr / ;

	model GAS_age_LOW = report_yr /noprint;
	plot GAS_age_LOW*report_yr ;

	model GAS_ltcf = report_yr /noprint;
	plot GAS_ltcf*report_yr;

run;



/*Cochran-Armitage Analysis here: (linear variables GE 0.50 R-sq)
GAS (overall) no C-A analysis but linearity tested
	Age:
age_med
	Race classes:
White
African American/Black
Other
	Gender:
Male
Female
	Ethnicity:
Hispanic 
Non-Hispanic


Mann-Kendall Analysis in R: (non-linear variables LT 0.50 R-sq)
Mortality
	Risk factors:
Injection drug use
Surgery
	Race classes:
American Indian/Alaska Native
Asian
*/




ods excel close;

/*Quick interpretation of C/A analysis: Row 1 level, value = 0 (not target), DECREASES as YEAR increases. So as we move forward in years there is a
  statistically significant increase in value = 1 at p<0.05 where applicapble */


ods graphics on;

proc lifetest data=sashelp.BMT plots=survival /*(cb=all test);*/;
time T * Status(0);
strata Group;
run;
