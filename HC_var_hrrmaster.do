// HC_var_hrrmaster.do

timestamp, output
// Creates a master do-file for prices and spending
use ${ddHC}/HC_externaldata_atlas_zipcrosswalk.dta, clear
keep hrr*
bys hrrnum: keep if _n==1
rename hrrnum merge_hrr
tempfile hrrlist
save `hrrlist', replace

foreach y in 2008 2009 2010 2011 avg {
tempfile build
loc ctr=0
revlist "${proclist}"
foreach proc in `r(rev)' {
	loc ++ctr
	use ${ddHC}/HC_epdata_hdata_`proc'.dta, clear

	qui gen pps = prov_pps
	cap drop price
	qui gen price = adj_price
	
	// Inflation adjust price
	if "`y'"=="avg" {
		gen year = ep_adm_y
		cpigen 
		qui summ cpi if year==2011
		qui replace cpi= cpi/r(mean)
		foreach v of varlist price pps {
			qui replace `v' = `v'/cpi
		}
	}
	else qui keep if ep_adm_y==`y'
	
	// Create wage adjusted price
	qui summ mci_wage_index if prov_hrrstate=="IL", mean
	qui replace mci_wage_index=mci_wage_index/r(mean)
	qui gen wageprice = price/mci_wage_index
	
	// Collapse to hospital level
	rename syshhi_15m hhi
	collapse (mean) price wageprice hhi pps (first) prov_hrrnum [aw=prov_vol], by(prov_e_npi) fast
	gen provs=1
	
	// Create market level measures of price and dispersion
	foreach v of varlist price wageprice pps {
		qui gen mean_`v' = `v'
		qui gen cv_`v' = `v'
		qui gen min_`v' = `v'
		qui gen max_`v' = `v'
	}
	// National min/max
	qui summ price, d
	loc nmax = r(max)
	loc nmin = r(min)
	loc nmaxmin = `nmax'/`nmin'
	
	collapse (mean) mean* hhi (sd) cv* (min) min* (max) max* (sum) provs, by(prov_hrrnum) fast
	
	qui gen mm_price = max_price/min_price
	drop max* min*

	foreach v of varlist cv* {
		loc m = subinstr("`v'","cv","mean",.)
		qui replace `v' = `v'/`m'
	}
	qui egen hhiq5 = xtile(hhi), nq(5)

	rename mean_price meanprice_`proc'
	rename cv_price cvprice_`proc'
	rename mean_wageprice meanwageprice_`proc'
	rename cv_wageprice cvwageprice_`proc'
	rename provs provct_`proc'
	rename mm_price mm_price_`proc'
	
	foreach v of varlist mean* {
		sort `v'
		qui gen `v'_rank = _n if `v'<.
	}
	
	// Create a national level observation
	set obs `=_N+1'
	qui replace prov_hrrnum=0 if prov_hrrnum==.
	foreach v of varlist mean* cv* mm* {
		qui summ `v', mean
		qui replace `v' = r(mean) if prov_hrrnum==0
	}
	qui replace mm_price_`proc'=`nmaxmin' if prov_hrrnum==0
	if "`proc'"!="ip" drop hhi* *pps*
	
	if `ctr'>1 {
		cap drop _merge
		merge 1:1 prov_hrrnum using `build'
		drop _merge
	}
	save `build', replace
}

cap drop _merge
qui gen merge_hrr = prov_hrr
if "`y'"=="avg" merge 1:1 merge_hrr using ${ddHC}/HC_var_spb_2011.dta
else merge 1:1 merge_hrr using ${ddHC}/HC_var_spb_`y'.dta
drop _merge

merge 1:1 merge_hrr using `hrrlist'
drop _merge


drop *spb_op *spb_phy
foreach v of varlist *spb* {
	sort `v'
	qui gen `v'_rank = _n if `v'<.
}
order prov_hrrnum hrr* *spb* 

outsheet using HC_var_hrrmaster_`y'.csv, comma replace

}

exit
