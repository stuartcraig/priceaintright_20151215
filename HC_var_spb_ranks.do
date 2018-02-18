/*--------------------------------------------------------------HC_var_spb_ranks.do
Create graphs exploring the relationship between
private and medicare SPB/E

Stuart Craig
Last updated 20151209
*/

timestamp, output

cap mkdir spbranks
cd spbranks
cap mkdir all

forvalues year=2008/2011 {

// Get the HRR names
use ${ddHC}/HC_externaldata_atlas_zipcrosswalk.dta, clear
keep hrr*
bys hrrnum: keep if _n==1
rename hrrnum merge_hrr
tempfile hrrlist
save `hrrlist', replace

use ${ddHC}/HC_var_spb_`year'.dta
merge m:1 merge_hrr using `hrrlist'

foreach t in ip op phy tot {
	gsort priv_spb_`t'
	gen `t'_rank = _n
}
foreach t in ip op phy tot {
	gsort medc_spb_`t'
	gen med_`t'_rank=_n
}
qui reg tot_rank med_tot_rank
loc beta = _b[med_tot_rank]
loc r = r(r2)
tw 		scatter tot_rank med_tot_rank, msize(medsmall) msymbol(circle) ///
	xline(153, lc(black)) yline(153, lc(black)) ///
	legend(off)	xtitle("Overall Medicare SPB rank") ytitle("Overall Private SPB rank") ysize(20) xsize(20)
graph export _HC_var_spbranks_tot_`year'.png, as(png) replace
graph export _HC_var_spbranks_tot_`year'.eps, as(eps) replace

tw 		scatter ip_rank med_ip_rank, msize(medsmall) msymbol(circle) ///
	xline(153, lc(black)) yline(153, lc(black)) ///
	legend(off)	xtitle("Inpatient Medicare SPB rank") ytitle("Inpatient Private SPB rank") ysize(20) xsize(20)
graph export _HC_var_spbranks_ip_`year'.eps, as(eps) replace
graph export _HC_var_spbranks_ip_`year'.eps, as(eps) replace


// Here we create the rank/rank figure highlighting Grand Junction, Lacrosse and Rochester MN
	qui reg tot_rank med_tot_rank
	loc beta = _b[med_tot_rank]
	loc r = r(r2)
	tw 		scatter tot_rank med_tot_rank, msize(medsmall) msymbol(circle) || ///
			scatter tot_rank med_tot_rank if merge_hrr==105, msize(large) msymbol(circle) mc("${red}") || ///
			scatter tot_rank med_tot_rank if merge_hrr==253, msize(large) msymbol(X) mc("${red}") mlw(thick) || ///
			scatter tot_rank med_tot_rank if merge_hrr==448, msize(large) msymbol(t) mc("${red}") mlw(thick) ///
		xline(153, lc(black)) yline(153, lc(black)) ///
		legend(order( 2 "Grand Junction, CO" 3 "Rochester, MN" 4 "La Crosse, WI"))	///
		xtitle("Overall Medicare Spending per Beneficiary Rank") ytitle("Overall Private Spending per Beneficiary Rank") ysize(20) xsize(20)
	graph export _HC_var_spbranks_tot_big3_`year'.png, as(png) replace
	graph export _HC_var_spbranks_tot_big3_`year'.eps, as(eps) replace
	
	
	tw 		scatter ip_rank med_ip_rank, msize(medsmall) msymbol(circle) || ///
			scatter ip_rank med_ip_rank if merge_hrr==105, msize(large) msymbol(circle) mc("${red}") || ///
			scatter ip_rank med_ip_rank if merge_hrr==253, msize(large) msymbol(X) mc("${red}") mlw(thick) || ///
			scatter ip_rank med_ip_rank if merge_hrr==448, msize(large) msymbol(t) mc("${red}") mlw(thick) ///
		xline(153, lc(black)) yline(153, lc(black)) ///
		legend(order( 2 "Grand Junction, CO" 3 "Rochester, MN" 4 "La Crosse, WI"))	///
		xtitle("Inpatient Medicare Spending per Beneficiary Rank") ytitle("Inpatient Private Spending per Beneficiary Rank") ysize(20) xsize(20)
	graph export _HC_var_spbranks_ip_big3_`year'.png, as(png) replace
	graph export _HC_var_spbranks_ip_big3_`year'.eps, as(eps) replace
	


// Do it again, with actual spending
	foreach v of varlist priv_spb_tot medc_spb_tot priv_spb_ip medc_spb_ip {
		format `v' %10.0fc
	}
	qui summ priv_spb_tot, d
	loc y = r(p50)
	qui summ medc_spb_tot, d
	loc x = r(p50)
	tw 		scatter priv_spb_tot medc_spb_tot, msize(medsmall) msymbol(circle) ///
		xline(`x', lc(black)) yline(`y', lc(black)) ///
		legend(off)	xtitle("Overall Medicare Spending per Beneficiary") ytitle("Overall Private Spending per Beneficiary") ysize(20) xsize(20)
	graph export _HC_var_spb_tot_`year'.png, as(png) replace
	graph export _HC_var_spb_tot_`year'.eps, as(eps) replace

	qui summ priv_spb_ip, d
	loc y = r(p50)
	qui summ medc_spb_ip, d
	loc x = r(p50)
	tw 		scatter priv_spb_ip medc_spb_ip, msize(medsmall) msymbol(circle) ///
		xline(`x', lc(black)) yline(`y', lc(black)) ///
		legend(off)	xtitle("Inpatient Medicare Spending per Beneficiary") ytitle("Inpatient Private Spending per Beneficiary") ysize(20) xsize(20)
	graph export _HC_var_spb_ip_`year'.png, as(png) replace
	graph export _HC_var_spb_ip_`year'.eps, as(eps) replace

}
*/

// Now create figures for each HRR, where we cycle through and highlight each one
cd all
// Get the HRR names
use ${ddHC}/HC_externaldata_atlas_zipcrosswalk.dta, clear
keep hrr*
bys hrrnum: keep if _n==1
rename hrrnum merge_hrr
tempfile hrrlist
save `hrrlist', replace

use ${ddHC}/HC_var_spb_2011.dta
merge m:1 merge_hrr using `hrrlist'

foreach t in ip op phy tot {
	gsort priv_spb_`t'
	gen `t'_rank = _n
}
foreach t in ip op phy tot {
	gsort medc_spb_`t'
	gen med_`t'_rank=_n
}

tw 		scatter tot_rank med_tot_rank, msize(medsmall) msymbol(circle)  ///
	xline(153, lc(black)) yline(153, lc(black)) ///
	legend(order( 2 "`city', `state'"))	///
	xtitle("Overall Medicare Spending per Beneficiary Rank") ytitle("Overall Private Spending per Beneficiary Rank") ysize(20) xsize(20)
graph export _HC_var_spbranks_tot_all.png, as(png) replace
graph export _HC_var_spbranks_tot_all.eps, as(eps) replace


tw 		scatter ip_rank med_ip_rank, msize(medsmall) msymbol(circle)  ///
	xline(153, lc(black)) yline(153, lc(black)) ///
	legend(order( 2 "`city', `state'"))	///
	xtitle("Inpatient Medicare Spending per Beneficiary Rank") ytitle("Inpatient Private Spending per Beneficiary Rank") ysize(20) xsize(20)
graph export _HC_var_spbranks_ip_all.png, as(png) replace
graph export _HC_var_spbranks_ip_all.eps, as(eps) replace
exit







// OLD

qui egen g = group(merge_hrr)
qui summ g
forvalues i=1/`r(max)' {
	qui levelsof hrrcity if g==`i', local(city)
	loc city = `city'
	qui levelsof hrrstate if g==`i', local(state)
	loc state = `state'
	qui summ merge_hrr if g==`i', mean
	loc num = r(mean)
	
	
	
	qui reg tot_rank med_tot_rank
	loc beta = _b[med_tot_rank]
	loc r = r(r2)
	tw 		scatter tot_rank med_tot_rank, msize(medsmall) msymbol(circle) || ///
			scatter tot_rank med_tot_rank if merge_hrr==`num', msize(large) msymbol(circle) mc("${red}")  ///
		xline(153, lc(black)) yline(153, lc(black)) ///
		legend(order( 2 "`city', `state'"))	///
		xtitle("Overall Medicare Spending per Beneficiary Rank") ytitle("Overall Private Spending per Beneficiary Rank") ysize(20) xsize(20)
	graph export _HC_var_spbranks_tot_all_`num'.png, as(png) replace
	graph export _HC_var_spbranks_tot_all_`num'.eps, as(eps) replace
	
	
	tw 		scatter ip_rank med_ip_rank, msize(medsmall) msymbol(circle) || ///
			scatter ip_rank med_ip_rank if merge_hrr==`num', msize(large) msymbol(circle) mc("${red}") ///
		xline(153, lc(black)) yline(153, lc(black)) ///
		legend(order( 2 "`city', `state'"))	///
		xtitle("Inpatient Medicare Spending per Beneficiary Rank") ytitle("Inpatient Private Spending per Beneficiary Rank") ysize(20) xsize(20)
	graph export _HC_var_spbranks_ip_all_`num'.png, as(png) replace
	graph export _HC_var_spbranks_ip_all_`num'.eps, as(eps) replace
	
	
	


}

exit
