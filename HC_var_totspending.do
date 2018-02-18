/*---------------------------------------------------------HC_var_totspending.do
Aggregate spending numbers directly totaled from the SQL tables.
	
Stuart Craig
Last updated 	20151209
*/

timestamp, output

	// Bring in spending totals from the SQL tables and inflation adjust
	use ${ddHC}/HC_raw_totspending.dta, clear
	cpigen
	qui summ cpi if year==2011, mean
	qui replace cpi = cpi/r(mean)
	foreach v of varlist spending* {
		qui replace `v' = `v'/cpi
	}
	drop cpi*
	outsheet using HC_var_totspending.csv, comma replace

exit
