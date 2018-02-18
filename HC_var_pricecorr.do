/*-----------------------------------------------------------HC_var_pricecorr.do
Produces pairwise correlation of prices
	
Stuart Craig
Last updated 	20151209
*/
timestamp, output

/*
-----------------------------------------------

Building a summary file of hospital prices

-----------------------------------------------
*/

	tempfile build
	loc ctr=0
	foreach proc of global proclist  {
		loc ++ctr
		
		use ${ddHC}/HC_epdata_hdata_`proc'.dta, clear
		loc pps ""
		if "`proc'"=="ip" loc pps "prov_pps"
		keep adj_price prov_e_npi prov_vol ep_adm_y `pps'
		rename adj_price price

		// Inflation adjust the risk adjusted prices
		cap gen year = ep_adm_y
		cpigen
		qui summ cpi if year==2011, mean
		qui replace cpi = cpi/`r(mean)' 
		qui replace price = price/cpi

		if "`proc'"=="ip" {
			qui gen price_med = prov_pps
			qui gen meanprice_med = prov_pps
		}
		
		// Collapse down to a hospital and build a wide file of all procs
		gen meanprice = price
		collapse (mean) meanprice* price* [aw=prov_vol], by(prov_e_npi) 
		rename price price_`proc'		  // weighted by that year's activity
		rename meanprice meanprice_`proc'
		if `ctr'>1 {
			cap drop _merge
			merge 1:1 prov_e_npi using `build'
			drop _merge
		}
		save `build', replace
	}

/*
-----------------------------------------------

Calculate correlation coefficients, storing
as columns

-----------------------------------------------
*/
	foreach v1 of varlist price* {
		loc v1n = subinstr("`v1'","price_","",.)
		foreach v2 of varlist price* {
			loc v2n = subinstr("`v2'","price_","",.)
			
			cap drop stdl
			cap drop stdr
			qui summ `v1' if `v1'<.&`v2'<.
			qui gen stdl = (`v1' - r(mean))/r(sd) if `v1'<.&`v2'<.
			qui summ `v2' if `v1'<.&`v2'<.
			qui gen stdr = (`v2' - r(mean))/r(sd) if `v1'<.&`v2'<.
			qui reg stdl stdr if `v1'<.&`v2'<.
			qui gen `v1n'_rho_`v2n' = _b[stdr]
		}
	}
	drop std*

/*
-----------------------------------------------

Collapse results to table format

-----------------------------------------------
*/	

	foreach v of varlist meanprice_* {
		loc vn = subinstr("`v'","meanprice_","",.)
		qui gen stdprice_`vn' = `v'
		qui gen minprice_`vn' = `v'
		qui gen maxprice_`vn' = `v'
		qui gen ctprice_`vn' = `v'
	}
	collapse (mean) meanprice* *rho* (sd) stdprice* (min) minprice* (max) maxprice* (count) ctprice*, fast
	qui gen i=.
	loc rlist "med_rho_"
	foreach proc of global proclist {
		loc rlist "`proc'_rho_ `rlist'"
	}
	reshape long meanprice_ stdprice_ minprice_ maxprice_ ctprice_ `rlist', i(i) j(proc) s
	qui gen maxminratio = maxprice/minprice
	drop maxprice minprice
	
	order proc mean std maxminratio ctprice ${proclist} med
	loc ctr = 0
	foreach proc of global proclist {	
		loc ctr = `ctr'+1
		
		qui replace i = `ctr' if proc=="`proc'"
	}
	sort i 
	outsheet using HC_var_pricecorr.csv, comma replace


exit
