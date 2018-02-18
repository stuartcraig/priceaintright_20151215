/*------------------------------------------------------------HC_var_spb_highlow.do
Create rank lists for cheap/expensive HRRs

Stuart Craig
Last updated 20151209
*/

timestamp, output

cap mkdir spbranks
cd spbranks

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

qui summ priv_spb_tot, mean
loc pmean = r(mean)
qui summ medc_spb_tot, mean
loc mmean = r(mean)

cap drop ip_compositerank
qui egen ip_compositerank = rowmean(ip_rank med_ip_rank)
cap drop tot_compositerank
qui egen tot_compositerank = rowmean(tot_rank med_tot_rank)

cap drop ip_divergence
cap drop tot_divergence
qui gen ip_divergence = ip_rank - med_ip_rank
qui gen tot_divergence = tot_rank - med_tot_rank


cap drop private
cap drop medicare
qui gen private = "cheap" 
qui gen medicare = "cheap"
sort tot_compositerank
tempfile t1
preserve
	keep private medicare merge_hrr* hrr* priv_spb_tot tot_rank medc_spb_tot med_tot_rank tot_compositerank
	keep in 1/10
	save `t1', replace
restore
 *outsheet private medicare merge_hrr* priv_spb_tot tot_rank medc_spb_tot med_tot_rank tot_compositerank using HC_paper1_spbrank.csv, comma replace

cap drop private
cap drop medicare
qui gen private = "expensive"
qui gen medicare = "expensive"
gsort -tot_compositerank
preserve
	keep private medicare merge_hrr* hrr* priv_spb_tot tot_rank medc_spb_tot med_tot_rank tot_compositerank
	keep in 1/10
	append using `t1'
	save `t1', replace
restore


cap drop private
cap drop medicare
qui gen private = "cheap"
qui gen medicare = "expensive"
sort tot_divergence
preserve
	keep private medicare merge_hrr* hrr* priv_spb_tot tot_rank medc_spb_tot med_tot_rank tot_divergence
	keep in 1/10
	append using `t1'
	save `t1', replace
restore


cap drop private
cap drop medicare
qui gen private = "expensive"
qui gen medicare = "cheap"
gsort -tot_divergence
preserve
	keep private medicare merge_hrr* hrr* priv_spb_tot tot_rank medc_spb_tot med_tot_rank tot_divergence
	keep in 1/10
	append using `t1'
	save `t1', replace
restore

use `t1', clear
set obs `=_N+1'
qui replace priv_spb_tot = `pmean' if priv_spb_tot==.
qui replace medc_spb_tot = `mmean' if medc_spb_tot==.
outsheet hrrcity hrrstate priv_spb_tot tot_rank medc_spb_tot med_tot_rank ///
		tot_compositerank tot_divergence private medicare ///
		using HC_var_spb_highlow.csv, comma replace

exit
