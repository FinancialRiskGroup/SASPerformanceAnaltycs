/*---------------------------------------------------------------
* NAME: table_variability.sas
*
* PURPOSE: Calculate variability in a returns data set.
*
* NOTES: Calculates mean absolute deviation, monthly standard deviation as well as annualized
	     standard deviation;
*
* MACRO OPTIONS:
* returns - required.  Data Set containing returns.
* scale- required.  Denotes the scale to annualize standard deviation.
* dateColumn- specifies the format of the date column in the returns data set. [Default= Date]
* outTable - output Data Set with variability statistics. [Default= variability_table]
* printTable- option to print output data set. {PRINT, NOPRINT} [Default= NOPRINT]
* MODIFIED:
* 6/29/2015 � DP - Initial Creation
*
* Copyright (c) 2015 by The Financial Risk Group, Cary, NC, USA.
*-------------------------------------------------------------*/
%macro table_variability(returns, 
								scale=,
								dateColumn= Date,
								outTable= variability_table,
								printTable= NOPRINT);
%local lib ds vars set1;

/***********************************
*Figure out 2 level ds name of PRICES
************************************/
%let lib = %scan(&returns,1,%str(.));
%let ds = %scan(&returns,2,%str(.));
%if "&ds" = "" %then %do;
	%let ds=&lib;
	%let lib=work;
%end;
%put lib:&lib ds:&ds;


/*******************************
*Get numeric fields in data set
*******************************/
proc sql noprint;
select name
	into :set1 separated by ' '
	from sashelp.vcolumn
	where libname = upcase("&lib")
	  and memname = upcase("&ds")
	  and type = "num"
	  and upcase(name) ^= upcase("&dateColumn");
quit;


%Standard_Deviation(&returns, scale= &scale, annualized= TRUE, outStdDev= annualized_StdDev);
%Standard_Deviation(&returns, scale= 1, outStdDev= Monthly);



proc means data= &returns mean noprint;
output out= meanData;
run;

data meanData;
set meanData;
drop _freq_ _type_ Date;
if _stat_ = 'N' then delete;
if _stat_ = 'STD' then delete;
if _stat_ = 'MIN' then delete;
if _stat_ = 'MAX' then delete;
run;

proc transpose data= meanData out= meanData;
run;
data meanData;
set meanData;
rename col1= Mean;
run;

proc transpose data= &returns out= price_t;
run;
data price_t;
set price_t;
if _name_= 'Date' then delete;
run;
proc sort data= price_t;
by _name_;
run;

proc sort data=  meanData;
by _name_;
run;

data merged;
merge price_t meanData;
by _name_;
run;

proc sql noprint;
select name
	into :vars separated by ' '
	from sashelp.vcolumn
	where libname = upcase("work")
	  and memname = upcase("merged")
	  and type= "num"
	  and upcase(name) ^= upcase("col1");
quit;

data merged(drop= i);
set merged;

array vars[*] &vars;

do i= 1 to dim(vars);
vars[i]= sum(vars[i], -(Mean));
vars[i]= abs(vars[i]);
end;

proc transpose data= merged out= merged;
run;

proc means data= merged mean noprint;
output out= MAD;

data MAD;
retain _stat_ &set1;
set MAD;
drop _type_ _freq_;
if _stat_ = 'N' then delete;
if _stat_ = 'STD' then delete;
if _stat_ = 'MIN' then delete;
if _stat_ = 'MAX' then delete;
drop _stat_;
run;

data &outTable;
/*retain Variability;*/
set MAD Monthly Annualized_StdDev;
if _n_= 1 then Variability= 'Mean Absolute Deviation';
if _n_= 2 then Variability= 'Monthly Standard Deviation';
if _n_= 3 then Variability= 'Annualized Standard Deviation';
run;

data &outTable;
retain Variability;
set &outTable;
run;

%if %upcase(&printTable) = PRINT %then %do;
	proc print data=&outTable noobs;
	run;
%end;

proc datasets lib= work nolist;
delete Monthly Annualized_StdDev MAD meanData merged price_t;
quit;

%mend;