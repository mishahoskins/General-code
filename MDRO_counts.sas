
/*
 *------------------------------------------------------------------------------
 * Program Name:  MDRO_counts_20250820 
 * Author:        Mikhail Hoskins
 * Date Created:  08/20/2025
 * Date Modified: .
 * Description:   Uses code: HAI_case_counts_20250812.sas and the HAI_updated working dataset to create an urban/rural breakdown of each MDRO.
				  
 *
 * Inputs:       HAI_case_counts_20250812.sas <-- run this first
 * Output:       none, table display within program
 * Notes:        
 *------------------------------------------------------------------------------
 */

/*Macros for population and disease*/
%let disease1 = CPO;

%let disease3 = GAS; 
%let disease4 = CAURIS;


/*State pop.*/
%let state_pop = 10835491;
%let ruraltotalpop = 3646750;
%let nonruralpop = 6792638;/*Urban + Suburban counties = 'Non-rural' from here: https://www.ncruralcenter.org/how-we-define-rural/*/
%let mindate = 01Jan2025; /*Minimum date you want to view (usually start of the year for monthly graphs). We also use this for the year max to make sure we're displaying non-complete data for the most recent year*/
%let maxmonth = 01Sep2025;/*Same as above but most recent month 1-denorm table month*/

libname analysis 'T:\HAI\Code library\Epi curve example\SASData';/*output path for sas7bdat file*/

proc sql;
create table min_max as
select

	max(event_date) as max_date format date9.,
	min(event_date) as min_date format date9.

from analysis.analysis
;
quit;

proc print data=min_max noobs;run;

/*Health Equity Cleaning, New Variables*/
data analysis;
set analysis.analysis;

	/*Rurality
			1=non-rural
			0=rural
	*/
	density=.;

	if owning_jd= "Alamance County"
	or owning_jd= "Buncombe County"
	or owning_jd= "Cabarrus County"
	or owning_jd= "Catawba County"
	or owning_jd= "Cumberland County"
	or owning_jd= "Davidson County"
	or owning_jd= "Durham County"
	or owning_jd= "Forsyth County"
	or owning_jd= "Gaston County"
	or owning_jd= "Guilford County"
	or owning_jd= "Henderson County"
	or owning_jd= "Iredell County"
	or owning_jd= "Johnston County"
	or owning_jd= "Lincoln County"
	or owning_jd= "Mecklenburg County"
	or owning_jd= "New Hanover County"
	or owning_jd= "Onslow County"
	or owning_jd= "Orange County"
	or owning_jd= "Pitt County"
	or owning_jd= "Rowan County"
	or owning_jd= "Union County"
	or owning_jd= "Wake County"

	then density=1;

	else density=0;

	/*SVI
		1= GE than 0.80
		0= LT than 0.80
	*/
		svi=.;

	if owning_jd= 'Lenoir County'
	or owning_jd= 'Robeson County'
	or owning_jd= 'Scotland County'
	or owning_jd= 'Greene County'
	or owning_jd= 'Halifax County'
	or owning_jd= 'Warren County'
	or owning_jd= 'Richmond County'
	or owning_jd= 'Vance County'
	or owning_jd= 'Bertie County'
	or owning_jd= 'Sampson County'
	or owning_jd= 'Anson County'
	or owning_jd= 'Wayne County'
	or owning_jd= 'Edgecombe County'
	or owning_jd= 'Wilson County'
	or owning_jd= 'Duplin County'
	or owning_jd= 'Columbus County'
	or owning_jd= 'Hertford County'
	or owning_jd= 'Cumberland County'
	or owning_jd= 'Swain County'
	or owning_jd= 'Hyde County'

	then svi=1;

	else svi=0;


	

run;

proc sql;
create table rename as
select *,

	intnx("month", (EVENT_DATE), 0, "end") as monthtag "Month Ending Date" format=monname.,
	intnx("year", (EVENT_DATE), 0, "end") as yeartag "Year Ending Date" format=year4.,

	case when type in ('STRA') then 'GAS' 
		 when type in ('CRE' , 'CPO') then 'CPO'

	else type end as type_new 

from analysis
	where type in ('STRA', 'CPO', 'CRE', 'CAURIS') 
		/*having monthtag GE ('01jan25'd)*/
;
/*Create a "tag" for everything but the most recent month, then a separate column for the most recent month. We'll make the transparency higher to indicate data may not be complete*/
create table cases_count as
select

	monthtag,
	yeartag,
	type_new,
	event_date,
	/*month tags*/
	case when (type_new) not in ('') and event_date LT ("&maxmonth"d) then 1 else . end as cases_tag,
	case when (type_new) not in ('') and event_date GE ("&maxmonth"d) then 1 else . end as recent_month_tag,

	/*year tags*/
	case when (type_new) not in ('') and yeartag LT ("&mindate"d) then 1 else . end as cases_tag_yr,
	case when (type_new) not in ('') and monthtag GE ("&mindate"d) then 1 else . end as  recent_yr_tag


from rename

;
quit;
proc print data=cases_count (obs=100); var  monthtag event_date cases_tag recent_month_tag type_new;where event_date ge ("&mindate"d);run;


proc freq data=cases_count; tables type_new*recent_month_tag /norow nocol nopercent nocum;run;

/*Macros because lazy*/
%macro metrics  (disease= );
proc sql;
create table quick_metrics as
select

	
	intnx("month", (EVENT_DATE), 0, "end") as testreportmonth "Month Ending Date" format=date11.,
/*
	sum (case when type_new in ("&disease" , "&disease2") and density in (1) then 1 else 0 end) as nonrural_&disease "Non-rural &disease + &disease2 per Quarter",
		(calculated nonrural_&disease / &nonruralpop) * 100000 as nonrural_ir_&disease "Non-rural IR/ 100,000K pop &disease + &disease2" format 10.2,

	sum (case when type_new in ("&disease" , "&disease2") and density in (0) then 1 else 0 end) as RURAL_&disease "Rural &disease + &disease2  per Quarter",
		(calculated RURAL_&disease / &ruraltotalpop) * 100000 as rural_ir_&disease "Rural IR/ 100,000K pop &disease + &disease2" format 10.2,

Total*/
			sum (case when type_new in ("&disease") then 1 else 0 end) as tot_&disease "Total &disease per Month",
		(calculated tot_&disease / &state_pop) * 100000 as ir_tot_&disease "Statewide IR/ 100,000K pop &disease" format 10.2



from rename
where EVENT_DATE ge ('01jan25'd)
	group by testreportmonth

;

quit;

proc print data=quick_metrics noobs label;run;


proc sgplot data=quick_metrics noborder noautolegend;

	/*series X=testreportqtr Y=nonrural_ir_&disease / datalabel lineattrs=(thickness=3)  datalabelattrs=(family="Arial" size=10);/* Plot for non-rural*/
	/*series X=testreportqtr Y=rural_ir_&disease / datalabel lineattrs=(thickness=3)  datalabelattrs=(family="Arial" size=10);/* Plot for non-rural*/

	series X=testreportmonth Y=tot_&disease / datalabel lineattrs=(thickness=3)  datalabelattrs=(family="Arial" size=10);

	xaxis label = "Month"
		valueattrs= (family="Arial" size=10)
		labelattrs= (family="Arial" weight= bold size=10)
		;

	yaxis label = "&disease cases"
		valueattrs= (family="Arial" size=10)
		labelattrs= (family="Arial" weight=bold size=10)
		;
		
		styleattrs datacolors= (vligb mogb ligb dagb pab grb libgr);	/*From: http://ftp.sas.com/techsup/download/graph/color_list.pdf
																				page 8 for greenscale colors used. Can use other 
																				scales/combinations but consitency would be beneficial*/

		    keylegend / title=" " location=outside position=topleft 
                across=1 noborder;

run;

%mend;

/*Macro for stacked bar graphs. Diabolical, lightly shaded last bar for most recent data to show incompleteness*/
%macro stack_graphs (timevar=, response_1=, response_2=, timeframe=, title= , color_schm=, disease=, startdate=);  
proc sgplot data = cases_count  noborder noautolegend noborder noautolegend;
/*year by cases up to current year (but not including current month), group by disease type, stack*/
vbar &timevar / response= &response_1 group =  type_new groupdisplay=stack fillattrs=(transparency=0.2)  outlineattrs=(color= '' thickness=0)

		datalabel
		datalabelattrs=(color=black size=10 family="Arial");

xaxis label = "&timeframe"
		valueattrs= (family="Arial" size=10)
		labelattrs= (family="Arial" weight= bold size=10)
		;

	yaxis label = "Number of Cases &title"
		valueattrs= (family="Arial" size=10)
		labelattrs= (family="Arial" weight=bold size=10)
		;

	styleattrs datacolors= &color_schm;

			    keylegend / title="MDRO:" titleattrs= (size=10 family="Arial" weight=bold) valueattrs= (size=10 family="Arial") location=outside position=topleft 
                across=3 noborder;

/*month by cases IN current month, group by disease type, stack*/
				/*Tricky SAS thing here: this needs to go after the keylegend so it doesn't display a separate legend for the lightly shaded "inocomplete" data.*/
vbar &timevar / response= &response_2 group = type_new groupdisplay=stack fillattrs=(transparency=0.8) outlineattrs=(color= VIYG thickness=0)

		datalabel
		datalabelattrs=(color=black size=10 family="Arial");

	where type_new in &disease and monthtag GE (&startdate);


run;
%mend;

dm 'odsresults; clear';


ods graphics /noborder;
title; footnote;
/*Set your output pathway here*/
ods excel file="T:\HAI\Code library\Epi curve example\analysis\MDRO_trends 2025_&sysdate..xlsx";*<----- Named a generic overwriteable name so we can continue to reproduce and autopopulate a template;

ods excel options (sheet_interval = "none" sheet_name = "&disease1" embedded_titles='Yes');
%metrics(disease=&disease1);

ods excel options (sheet_interval = "now" sheet_name = "&disease3" embedded_titles='Yes');
%metrics(disease=&disease3);

ods excel options (sheet_interval = "now" sheet_name = "&disease4" embedded_titles='Yes');
%metrics(disease=&disease4);




/*Monthly plots*/
ods excel options (sheet_interval = "now" sheet_name = "bar monthly" embedded_titles='Yes');
/*Monthly graphs*/
%stack_graphs(timevar= monthtag, response_1= cases_tag, response_2= recent_month_tag, timeframe= Month, title= (CPO + C.auris), color_schm= (DEYPK STB), disease= ("CPO" "CAURIS"), startdate="&mindate"d);
%stack_graphs(timevar= monthtag, response_1= cases_tag, response_2= recent_month_tag, timeframe = Month, title = (GAS), color_schm = (DEYG), disease = ("GAS"), startdate="&mindate"d);

/*Annual plots*/
ods excel options (sheet_interval = "now" sheet_name = "bar annual" embedded_titles='Yes');
/*Annual graphs*/
%stack_graphs(timevar= yeartag, response_1= cases_tag_yr, response_2= recent_yr_tag, timeframe= Year, title= (CPO + C.auris), color_schm= (STB DEYPK), disease= ("CPO" "CAURIS"), startdate="01jan2015"d);
%stack_graphs(timevar= yeartag, response_1= cases_tag_yr, response_2= recent_yr_tag, timeframe = Year, title = GAS, color_schm = (DEYG), disease = ("GAS"), startdate="01jan2015"d);

ods excel close;
