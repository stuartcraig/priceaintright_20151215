/*-------------------------------------------------------------HC_paper1_pricemaps.do
Map price data for all procs

Stuart Craig
Last updated 20151209
*/

timestamp, output

tempfile build
loc ctr=0
revlist "${proclist}"
foreach proc in `r(rev)' {
	loc ++ctr
	use ${ddHC}/HC_epdata_hdata_`proc'.dta, clear

	cap drop price
	cap drop medicare
	rename adj_price price
	rename prov_pps medicare
	
	// Center everything at 2011
	qui gen year = ep_adm_y 
	cpigen
	qui summ cpi if year==2011, mean
	qui replace cpi = cpi/r(mean)
	foreach v of varlist price medicare {
		qui replace `v' = `v'/cpi
	}
	*/
	
	// Create wage adjusted prices (center at IL)
	pfixdrop merge
	qui gen merge_npi = prov_e_npi
	qui gen merge_year = ep_adm_y
	cap drop _merge
	merge m:1 merge* using ${ddHC}/HC_externaldata_cms_mci.dta, keepusing(mci_wage_index)
	drop if _m<3 // should already be the case
	qui summ mci_wage_index if prov_hrrstate=="IL", mean
	qui gen wageprice = price/(mci_wage_index/r(mean))
	
	
	collapse (mean) price medicare wageprice (first) prov_hrrnum [aw=prov_vol], by(prov_e_npi) fast
	
	cap drop provs
	gen provs=1 // count the providers so we know what we can/can't release
	collapse (mean) price medicare wageprice (sum) provs, by(prov_hrrnum) fast

	rename price `proc'_price
	rename provs `proc'_provs
	rename wageprice `proc'_wageprice
	
	// Keep the PPS payments averaged for the IP sample!
	if "`proc'"=="ip" rename medicare med_price
	else drop medicare
	
	// Stack the files horizontally
	if `ctr'>1 {
		cap drop _merge
		merge 1:1 prov_hrrnum using `build'
		drop _merge
	}
	save `build', replace
}
outsheet using HC_var_pricemaps_data.csv, comma replace


exit


