%macro Find_Drawdowns_test2(keep=FALSE);
%global pass notes;

%if &keep=FALSE %then %do;
	filename x temp;
%end;
%else %do;
	filename x "&dir\Find_Drawdowns_test2_submit.sas";
%end;

data _null_;
file x;
put "submit /r;";
put "require(PerformanceAnalytics)";
put "prices = as.xts(read.zoo('&dir\\prices.csv',";
put "                 sep=',',";
put "                 header=TRUE";
put "                 )";
put "		)";
put "returns = na.omit(Return.calculate(prices, method='log'))";
put "drawdowns=findDrawdowns(returns, geometric=FALSE)";
put "returns=drawdowns[[1]]";
put "for(i in 2:7) {";
put "  returns=cbind(returns,drawdowns[[i]])";
put "}";
put "colnames(returns) = c('return','begin','trough','end','length','peaktotrough','recovery')";
put "endsubmit;";
run;

proc iml;
%include x;

call importdatasetfromr("returns_from_R","returns");
quit;


data prices;
set input.prices;
run;

%return_calculate(prices,updateInPlace=TRUE,method=LOG)
%Find_Drawdowns(prices,asset=IBM,method= LOG,SortDrawdown= FALSE);


/*If tables have 0 records then delete them.*/
proc sql noprint;
 %local nv;
 select count(*) into :nv TRIMMED from FindDrawdowns;
 %if ^&nv %then %do;
 	drop table FindDrawdowns;
 %end;
 
 select count(*) into :nv TRIMMED from returns_from_r;
 %if ^&nv %then %do;
 	drop table returns_from_r;
 %end;
quit ;

%if ^%sysfunc(exist(FindDrawdowns)) %then %do;
/*Error creating the data set, ensure compare fails*/
data FindDrawdowns;
	return = -999;
	begin = return;
	trough = return;
	end = return;
	length = return;
	peaktotrough = return;
	recovery = return;
run;
%end;

%if ^%sysfunc(exist(returns_from_r)) %then %do;
/*Error creating the data set, ensure compare fails*/
data returns_from_r;
	return = -999;
	begin = return;
	trough = return;
	end = return;
	length = return;
	peaktotrough = return;
	recovery = return;
run;
%end;

proc compare base=returns_from_r 
			 compare=FindDrawdowns 
			 out=diff(where=(_type_ = "DIF"
			            and (fuzz(return) or fuzz(begin) or fuzz(trough) 
			              or fuzz(end) or fuzz(length) or fuzz(peaktotrough) or fuzz(recovery)
					)))
			 noprint;
run;


data _null_;
if 0 then set diff nobs=n;
call symputx("n",n,"l");
stop;
run;

%if &n = 0 %then %do;
	%put NOTE: NO ERROR IN TEST FIND_DRAWDOWNS_TEST2;
	%let pass=TRUE;
	%let notes=Passed;
%end;
%else %do;
	%put ERROR: PROBLEM IN TEST FIND_DRAWDOWNS_TEST2;
	%let pass=FALSE;
	%let notes=Differences detected in outputs.;
%end;

%if &keep=FALSE %then %do;
	proc datasets lib=work nolist;
	delete diff prices FindDrawdowns returns_from_r;
	quit;
%end;

%mend;
