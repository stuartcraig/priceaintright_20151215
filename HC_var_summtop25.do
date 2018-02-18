/*-------------------------------------------------------------HC_var_summtop25.do

Stuart Craig
Last updated 20151209
*/
timestamp, output




/*
-----------------------------------------------------

Create a list of the 25 most populated HRRs

-----------------------------------------------------
*/
	use ${ddHC}/enrollment/HC_enrollment_all.dta, clear
	collapse (sum) enrollee_equiv, by(merge_hrr) fast // do it across years
	gsort -enrollee_equiv
	
	keep in 1/25
	tempfile hrrpop
	save `hrrpop', replace

/*
-----------------------------------------------------

Calculate the mean and relative sd for each of the
HRRs across all clinical cohorts

-----------------------------------------------------
*/
	loc ctr=0
	foreach proc of global proclist {
		loc ++ctr
		use ${ddHC}/HC_epdata_hdata_`proc'.dta, clear
		cap drop price
		qui gen price = adj_price
		cap gen year = ep_adm_y
		
		cpigen
		qui summ cpi if year==2011, mean
		qui replace cpi = cpi/r(mean)
		qui replace price = price/cpi
		qui gen medicare = medprice/cpi
		if "`proc'"=="ip" qui replace medicare = prov_pps/cpi
		collapse (mean) price medicare (first) prov_hrr* [aw=prov_vol], by(prov_e_npi) fast
		
		/*
		// National mean and cov
		qui summ price, d
		loc np = r(mean) 
		loc cv = r(sd)/r(mean)
		*/
		// Mean and SD price per proc
		foreach s in mean cov {
			qui gen `s'_`proc' = price
			qui gen `s'_med`proc' = medicare
		}
		*/
		// Count the hospitals (must have 5+?)
		qui gen prov_count_`proc'=1
		collapse (mean) mean* (sd) cov* (sum) prov_count_`proc', by(prov_hrr*) fast
		qui replace cov_`proc' = cov_`proc'/mean_`proc' // standardize w/ mean
		qui replace cov_med`proc' = cov_med`proc'/mean_med`proc'
		
		// Popualte the national average (now average ACROSS HRRs)
		set obs `=_N+1'
		qui replace prov_hrrnum = -9 if prov_hrrnum==.
		qui summ mean_`proc'
		qui replace mean_`proc' = r(mean) if prov_hrrnum==-9
		qui summ cov_`proc'
		qui replace cov_`proc'  = r(mean) if prov_hrrnum==-9 
		
		set obs `=_N+1'
		qui replace prov_hrrnum = -8 if prov_hrrnum==.
		qui summ mean_med`proc'
		qui replace mean_`proc' = r(mean) if prov_hrrnum==-8
		qui summ cov_med`proc'
		qui replace cov_`proc'  = r(mean) if prov_hrrnum==-8
		drop *med*
		
		cap drop merge_hrr
		qui gen merge_hrr = prov_hrrnum
		// Accumulate the cohorts
		cap drop _merge
		merge 1:1 merge_hrr using `hrrpop'
		keep if _m>1|inlist(merge_hrr,-8,-9)
		drop _merge
		save `hrrpop', replace
	}
	
	drop merge_hrr
	order prov* *_ip *hip *knr *delc *delv *ptca *col
	outsheet using HC_var_summtop25.csv, comma replace
exit
