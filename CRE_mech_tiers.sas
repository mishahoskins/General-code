
/*
 *------------------------------------------------------------------------------
 * Program Name:  CRE_mech_tiers_20250618
 * Author:        Mikhail Hoskins
 * Date Created:  06/18/2025
 * Date Modified: 
 * Description:   Quick look at tiers of CREs and if we can apply an epidemiological method to classification.
 *
 * Inputs:       SASdata.recordssas (from MDRO quarterly reports).
 * Output:       .
 * Notes:         
 *				
 *				
 *				
 *
 *------------------------------------------------------------------------------
 */



/*Part III: Pull in source data for a year over year look*/
proc sql;
create table five_yr_graph as
select

	intnx("year", (EVENT_DATE), 0, "end") as reportyr "Year Ending Date" format=year4.,
	sum (case when type in ("&disease") then 1 else 0 end) as case_count "Cases in Year"

from SASdata.recordssas
	where mechanism in ("OXA-48")
	group by reportyr
				;



quit;


/*create 3 week moving average for case comparison*/
data five_yr_graph;
set five_yr_graph;

label case_3_avg = "3-Year Case Average";
format case_3_avg 8.;
/*Average based on three year lag*/
case_3_avg=(case_count+lag(case_count)+lag2(case_count))/3;

run;
title;footnote;
ods graphics /noborder;
proc sgplot data=five_yr_graph noborder noautolegend;

  series X=reportyr Y=case_count /  lineattrs=(thickness=3);/* Plot for the current year */
  series X=reportyr Y=case_3_avg /  lineattrs=(thickness=1 pattern=dashed color=red); /*Plot for the current year */ /* Plot for the 5-year average */

	xaxis label = "Year"
		valueattrs= (family="Arial" size=10)
		labelattrs= (family="Arial" weight= bold size=10)
		values=('31dec2018'd to '31dec2024'd by year) valuesdisplay=('2018' '2019' '2020' '2021' '2022' '2023' '2024');

	yaxis label = "Number of &disease cases"
		valueattrs= (family="Arial" size=10)
		labelattrs= (family="Arial" weight=bold size=10)
		min=0 max=100;

		
		styleattrs datacolors= (vligb mogb ligb dagb pab grb libgr);	/*From: http://ftp.sas.com/techsup/download/graph/color_list.pdf
																				page 8 for greenscale colors used. Can use other 
																				scales/combinations but consitency would be beneficial*/

		    keylegend / title=" " location=inside position=topleft 
                across=1 noborder;

run;

proc print data=five_yr_graph noobs label;run;

proc sql;
create table five_yr_C_A as
select 

	intnx("year", (EVENT_DATE), 0, "end") as reportyr "Year Ending Date" format=year4.,
	mechanism,
	/*Mechanism specific*/
	case when mechanism in ('KPC') then 1 else 0 end as KPC_val,
	case when mechanism in ('NDM') then 1 else 0 end as NDM_val,
	case when mechanism in ('VIM') then 1 else 0 end as VIM_val,
	case when mechanism in ('IMP') then 1 else 0 end as IMP_val,
	case when mechanism in ('OXA-48') then 1 else 0 end as OXA48_val
	
from SASdata.recordssas
;
quit;



title; footnote;
/*Set your output pathway here*/
ods excel file="C:\Users\mhoskins1\Desktop\Work Files\CRE_c_a_analysis_&sysdate..xlsx";

ods excel options (sheet_interval = "now" sheet_name = "case/ir tables" embedded_titles='Yes');
proc freq data=five_yr_C_A; 

	table   KPC_val*reportyr NDM_val*reportyr VIM_val*reportyr IMP_val*reportyr OXA48_val*reportyr 
											/ trend norow nocol nopercent scores=table
															    plots=freqplot(twoway=stacked); 
		
run; 
ods excel close;
