/*---------------------------------------------------------------HC_var_spb_riskadjust.do

Stuart Craig
Last updated 20151209
*/


timestamp, output
// Put this in a subfolder
cap mkdir spb
cd spb

	
/*
---------------------------------------------

Create risk adjusted SPB files

---------------------------------------------
*/	

forvalues y=2007/2011 {
		di "=========================================================="
		di "				`y'"
		di "=========================================================="
		
	//-------------------------------- 1. Calculate private spending per beneficiary
		use ${ddHC}/HC_raw_spbrollup_`y'.dta, clear
		
		// First calculate national enrollment (enrollee year equivalents)
		// and national spb
		qui summ enroll_month
		loc b_n = r(mean)*r(N)/12 // Bn
		foreach t in ip op phy tot {
			qui summ spending_`t'
			loc nat_spb_`t' = r(mean)*r(N)/`b_n'
		}
		
		// Next, calculate national subgroup SPB 
		collapse (sum) spending* enroll_month, by(pat_age pat_gender) fast
		qui gen b_tot = enroll_month/12
		foreach t in ip op phy tot {
			qui gen nat_sub_spb_`t' = spending_`t'/b_tot
		}
		tempfile nat
		save `nat', replace
		
		// Create expected observed SPB ratio at HRR level
		use ${ddHC}/HC_raw_spbrollup_`y'.dta, clear
		collapse (sum) spending* enroll_month, by(pat_age pat_gender pat_hrrnum) fast
		qui gen b_hi = enroll_month/12 // beneficiaries for HRR h and subgroup i
		foreach t in ip op phy tot {
			qui gen o_spb_`t' = spending_`t'
		}
		
		cap drop _merge
		merge m:1 pat_age pat_gender using `nat'
		assert _merge==3
		drop _merge
		
		// Predict spending off Si and Bhi for each subgroup i
		foreach t in ip op phy tot {
			qui gen e_spb_`t' = b_hi*nat_sub_spb_`t' // predict spending off Bhi and Si
		}
		// Sum up and divide by beneficiaries
		collapse (sum) e_spb* o_spb* b_hi, by(pat_hrr) fast
		foreach v of varlist e_spb* o_spb* {
			qui replace `v' = `v'/b_hi
		}
		
		// Adjusted SPB is (observed/expected)*average
		foreach t in ip op phy tot {
			qui gen adj_`t' = (o_spb_`t'/e_spb_`t')*`nat_spb_`t''
		}
		
	//-------------------------------- 2. Bring in the ATLAS data on Medicare SPB

		cap drop _merge
		pfixdrop merge
		qui gen merge_year = `y' // the spending file does not carry around the year, so we pull it from the loop 
		qui gen merge_hrr = pat_hrrnum
		merge 1:1 merge_year merge_hrr using ${ddHC}/HC_externaldata_atlas_reimb.dta
		drop if _m<3
		drop _merge
		
		
		foreach t in ip op phy tot {
			rename atlas_spb_`t' medc_spb_`t'
			rename adj_`t' 		 priv_spb_`t'
		}
		keep merge_hrr merge_year medc_spb* priv_spb* 
		save ${ddHC}/HC_var_spb_`y'.dta, replace
	
}
//-------------------------------- 3. Make a table describing this data
	
forvalues y=2007/2011 {	
	use ${ddHC}/HC_var_spb_`y'.dta, clear

	/* FOR NOW THIS IS OMITTED */
	keep merge* *ip *tot
	
	
	corr priv_spb_tot priv_spb_ip
	loc priv_corr = r(rho)
	corr medc_spb_tot medc_spb_ip
	loc medc_corr = r(rho)
	corr priv_spb_tot medc_spb_tot
	loc pmtot_corr = r(rho)
	corr priv_spb_ip  medc_spb_ip
	loc pmip_corr = r(rho)
	
	foreach v of varlist *ip *tot {
		qui gen `v'_N =`v'
		qui gen `v'_mean = `v'
		qui gen `v'_sd = `v'
		qui gen `v'_p90 = `v'
		qui gen `v'_p10 = `v'
	}
	collapse (mean) *mean (sd) *sd (p90) *p90 (p10) *p10 (count) *N, fast
	
	// Generate the correlations (they'll all go on the right)
	foreach x in priv medc pmtot pmip {
		qui gen `x'_corr = ``x'_corr'
	}
	
	// Replace sd with cov
	foreach v of varlist *sd {
		loc vn = subinstr("`v'","sd","cov",.)
		loc vs = subinstr("`v'","sd","",.)
		qui replace `v' = `vs'sd/`vs'mean
		rename `v' `vn'
	}
	
	// Create 90/10 measures
	foreach t in priv_spb_tot priv_spb_ip medc_spb_tot medc_spb_ip {
		qui gen `t'_p90p10 = `t'_p90/`t'_p10
		drop `t'_p90 `t'_p10
	}
	
	// Shape the table
	qui gen i=.
	reshape long priv_spb_ip_ priv_spb_tot_ medc_spb_ip_ medc_spb_tot_, i(i) j(stat) s
	qui replace i = 1 if stat=="mean"
	qui replace i = 2 if stat=="sd"
	qui replace i = 3 if stat=="cov"
	qui replace i = 4 if stat=="p90p10"
	
	order i stat priv_spb* medc_spb* priv_corr* medc_corr*
	sort i
	list
	
	outsheet using HC_var_spb_table_`y'.csv, comma replace
}



// Repeat the exercise for different levels of restriction (now over/under 20)
forvalues y=2007/2011 {
	foreach c in 20 {
		foreach side in over under {	
			
			cap log close
			log using HC_paper1_spb_`y'_hc`side'`c'.txt, text replace
			
		//-------------------------------- 1. Calculate private spending per beneficiary
			
			// Create the HRR/state key
			tempfile hrrstates
			use ${ddHC}/HC_externaldata_atlas_zipcrosswalk.dta, clear
			keep hrr* 
			bys hrrnum: keep if _n==1
			rename hrrnum merge_hrr
			save `hrrstates', replace
			
			use ${ddHC}/HC_raw_spbrollup_`y'.dta, clear
			
			// Isolate the HRRs meeting the current coverage criterion
				//---------------------------------------------------------
				cap drop _merge
				cap drop merge_hrr
				qui gen merge_hrr = pat_hrrnum
				merge m:1 merge_hrr using `hrrstates'
				drop if _merge<3
				cap drop _merge
				cap drop merge_state
				qui gen merge_state = hrrstate
				merge m:1 merge_state using ${ddHC}/HC_raw_statecoverage.dta // don't have this for all years!
				if "`side'"=="over" keep if cov>`c'&cov<.
				else keep if cov<=`c'
				//---------------------------------------------------------
				
			// First calculate national enrollment (enrollee year equivalents)
			// and national spb
			qui summ enroll_month
			loc b_n = r(mean)*r(N)/12 // Bn
			foreach t in ip op phy tot {
				qui summ spending_`t'
				loc nat_spb_`t' = r(mean)*r(N)/`b_n'
			}
			
			// Next, calculate national subgroup SPB 
			collapse (sum) spending* enroll_month, by(pat_age pat_gender) fast
			qui gen b_tot = enroll_month/12
			foreach t in ip op phy tot {
				qui gen nat_sub_spb_`t' = spending_`t'/b_tot
			}
			tempfile nat
			save `nat', replace
			
			// Create expected observed SPB ratio at HRR level
			use ${ddHC}/HC_raw_spbrollup_`y'.dta, clear
			
			// Isolate the HRRs meeting the current coverage criterion
				//---------------------------------------------------------
				cap drop _merge
				cap drop merge_hrr
				qui gen merge_hrr = pat_hrrnum
				merge m:1 merge_hrr using `hrrstates'
				drop if _merge<3
				cap drop _merge
				cap drop merge_state
				qui gen merge_state = hrrstate
				merge m:1 merge_state using ${ddHC}/HC_raw_statecoverage.dta
				if "`side'"=="over" keep if cov>`c'&cov<.
				else keep if cov<=`c'
				//---------------------------------------------------------
			
			collapse (sum) spending* enroll_month, by(pat_age pat_gender pat_hrrnum) fast
			qui gen b_hi = enroll_month/12 // beneficiaries for HRR h and subgroup i
			foreach t in ip op phy tot {
				qui gen o_spb_`t' = spending_`t'
			}
			
			cap drop _merge
			merge m:1 pat_age pat_gender using `nat'
			assert _merge==3
			drop _merge
			
			// Predict spending off Si and Bhi for each subgroup i
			foreach t in ip op phy tot {
				qui gen e_spb_`t' = b_hi*nat_sub_spb_`t' // predict spending off Bhi and Si
			}
			// Sum up and divide by beneficiaries
			collapse (sum) e_spb* o_spb* b_hi, by(pat_hrr) fast
			foreach v of varlist e_spb* o_spb* {
				qui replace `v' = `v'/b_hi
			}
			
			// Adjusted SPB is (observed/expected)*average
			foreach t in ip op phy tot {
				qui gen adj_`t' = (o_spb_`t'/e_spb_`t')*`nat_spb_`t''
			}
			
		//-------------------------------- 2. Bring in the ATLAS data on Medicare SPB

			cap drop _merge
			pfixdrop merge
			qui gen merge_year = `y' 
			qui gen merge_hrr = pat_hrrnum
			merge 1:1 merge_year merge_hrr using ${ddHC}/HC_externaldata_atlas_reimb.dta
			drop if _m<3
			drop _merge
			
			
			foreach t in ip op phy tot {
				rename atlas_spb_`t' medc_spb_`t'
				rename adj_`t' 		 priv_spb_`t'
			}
			
			save ${ddHC}/HC_var_spb_`y'_hc`side'`c'.dta
			outsheet merge_hrr merge_year medc_spb* priv_spb* using HC_var_spb_`y'_hc`side'`c'.csv, comma replace

		//-------------------------------- 3. Make a table describing this data

			/* FOR NOW THIS IS OMITTED */
			keep merge* *ip *tot
			drop e_* o_* 
			
			corr priv_spb_tot priv_spb_ip
			loc priv_corr = r(rho)
			corr medc_spb_tot medc_spb_ip
			loc medc_corr = r(rho)
			corr priv_spb_tot medc_spb_tot
			loc pmtot_corr = r(rho)
			corr priv_spb_ip  medc_spb_ip
			loc pmip_corr = r(rho)
			
			foreach v of varlist *ip *tot {
				qui gen `v'_N =`v'
				qui gen `v'_mean = `v'
				qui gen `v'_sd = `v'
				qui gen `v'_p90 = `v'
				qui gen `v'_p10 = `v'
			}
			collapse (mean) *mean (sd) *sd (p90) *p90 (p10) *p10 (count) *N, fast
			
			// Generate the correlations (they'll all go on the right)
			foreach x in priv medc pmtot pmip {
				qui gen `x'_corr = ``x'_corr'
			}
			
			// Replace sd with cov
			foreach v of varlist *sd {
				loc vn = subinstr("`v'","sd","cov",.)
				loc vs = subinstr("`v'","sd","",.)
				qui replace `v' = `vs'sd/`vs'mean
				rename `v' `vn'
			}
			
			// Create 90/10 measures
			foreach t in priv_spb_tot priv_spb_ip medc_spb_tot medc_spb_ip {
				qui gen `t'_p90p10 = `t'_p90/`t'_p10
				drop `t'_p90 `t'_p10
			}
			
			
			
			qui gen i=.
			reshape long priv_spb_ip_ priv_spb_tot_ medc_spb_ip_ medc_spb_tot_, i(i) j(stat) s
			qui replace i = 1 if stat=="mean"
			qui replace i = 2 if stat=="sd"
			qui replace i = 3 if stat=="cov"
			qui replace i = 4 if stat=="p90p10"
			
			order i stat priv_spb* medc_spb* priv_corr* medc_corr*
			sort i
			list
			outsheet using HC_var_spb_table_`y'_hc`side'`c'.csv, comma replace
			
			log close
		}	
	}	
}



// Again for BCBS--top/bottom 50%
forvalues y=2007/2011 {
	foreach side in over under {	
		cap log close // now over/under median!
		log using HC_var_spb_`y'_bcbs`side'.txt, text replace
		
	//-------------------------------- 1. Calculate private spending per beneficiary
		
		// Create the HRR/state key
		tempfile hrrstates
		use ${ddHC}/HC_externaldata_atlas_zipcrosswalk.dta, clear
		keep hrr* 
		bys hrrnum: keep if _n==1
		rename hrrnum merge_hrr
		save `hrrstates', replace
		
		use ${ddHC}/HC_raw_spbrollup_`y'.dta, clear
		
		// Isolate the HRRs meeting the current coverage criterion
			//---------------------------------------------------------
			cap drop _merge
			cap drop merge_hrr
			qui gen merge_hrr = pat_hrrnum
			merge m:1 merge_hrr using `hrrstates'
			drop if _merge<3
			cap drop _merge
			cap drop merge_state
			qui gen merge_state = hrrstate
			merge m:1 merge_state using ${ddHC}/HC_externaldata_cciio_statehhis.dta, keepusing(cciio*bcbs*)
			if "`side'"=="over" keep if inlist(cciio_q4bcbs,3,4)
			else keep if inlist(cciio_q4bcbs,1,2)
			//---------------------------------------------------------
			
		// First calculate national enrollment (enrollee year equivalents)
		// and national spb
		qui summ enroll_month
		loc b_n = r(mean)*r(N)/12 // Bn
		foreach t in ip op phy tot {
			qui summ spending_`t'
			loc nat_spb_`t' = r(mean)*r(N)/`b_n'
		}
		
		// Next, calculate national subgroup SPB 
		collapse (sum) spending* enroll_month, by(pat_age pat_gender) fast
		qui gen b_tot = enroll_month/12
		foreach t in ip op phy tot {
			qui gen nat_sub_spb_`t' = spending_`t'/b_tot
		}
		tempfile nat
		save `nat', replace
		
		// Create expected observed SPB ratio at HRR level
		use ${ddHC}/HC_raw_spbrollup_`y'.dta, clear
		
		// Isolate the HRRs meeting the current coverage criterion
			//---------------------------------------------------------
			cap drop _merge
			cap drop merge_hrr
			qui gen merge_hrr = pat_hrrnum
			merge m:1 merge_hrr using `hrrstates'
			drop if _merge<3
			cap drop _merge
			cap drop merge_state
			qui gen merge_state = hrrstate
			merge m:1 merge_state using ${ddHC}/HC_externaldata_cciio_statehhis.dta, keepusing(cciio*bcbs*)
			if "`side'"=="over" keep if inlist(cciio_q4bcbs,3,4)
			else keep if inlist(cciio_q4bcbs,1,2)
			//---------------------------------------------------------
		
		collapse (sum) spending* enroll_month, by(pat_age pat_gender pat_hrrnum) fast
		qui gen b_hi = enroll_month/12 // beneficiaries for HRR h and subgroup i
		foreach t in ip op phy tot {
			qui gen o_spb_`t' = spending_`t'
		}
		
		cap drop _merge
		merge m:1 pat_age pat_gender using `nat'
		assert _merge==3
		drop _merge
		
		// Predict spending off Si and Bhi for each subgroup i
		foreach t in ip op phy tot {
			qui gen e_spb_`t' = b_hi*nat_sub_spb_`t' // predict spending off Bhi and Si
		}
		// Sum up and divide by beneficiaries
		collapse (sum) e_spb* o_spb* b_hi, by(pat_hrr) fast
		foreach v of varlist e_spb* o_spb* {
			qui replace `v' = `v'/b_hi
		}
		
		// Adjusted SPB is (observed/expected)*average
		foreach t in ip op phy tot {
			qui gen adj_`t' = (o_spb_`t'/e_spb_`t')*`nat_spb_`t''
		}
		
	//-------------------------------- 2. Bring in the ATLAS data on Medicare SPB

		cap drop _merge
		pfixdrop merge
		qui gen merge_year = `y' 
		qui gen merge_hrr = pat_hrrnum
		merge 1:1 merge_year merge_hrr using ${ddHC}/HC_externaldata_atlas_reimb.dta
		drop if _m<3
		drop _merge
		
		
		foreach t in ip op phy tot {
			rename atlas_spb_`t' medc_spb_`t'
			rename adj_`t' 		 priv_spb_`t'
		}
		
		save ${ddHC}/HC_var_spb_`y'_bcbs`side'.dta
		outsheet merge_hrr merge_year medc_spb* priv_spb* using HC_var_spb_`y'_bcbs`side'.csv, comma replace

	//-------------------------------- 3. Make a table describing this data

		/* FOR NOW THIS IS OMITTED */
		keep merge* *ip *tot
		drop e_* o_* 
		
		corr priv_spb_tot priv_spb_ip
		loc priv_corr = r(rho)
		corr medc_spb_tot medc_spb_ip
		loc medc_corr = r(rho)
		corr priv_spb_tot medc_spb_tot
		loc pmtot_corr = r(rho)
		corr priv_spb_ip  medc_spb_ip
		loc pmip_corr = r(rho)
		
		foreach v of varlist *ip *tot {
			qui gen `v'_N =`v'
			qui gen `v'_mean = `v'
			qui gen `v'_sd = `v'
			qui gen `v'_p90 = `v'
			qui gen `v'_p10 = `v'
		}
		collapse (mean) *mean (sd) *sd (p90) *p90 (p10) *p10 (count) *N, fast
		
		// Generate the correlations (they'll all go on the right)
		foreach x in priv medc pmtot pmip {
			qui gen `x'_corr = ``x'_corr'
		}
		
		// Replace sd with cov
		foreach v of varlist *sd {
			loc vn = subinstr("`v'","sd","cov",.)
			loc vs = subinstr("`v'","sd","",.)
			qui replace `v' = `vs'sd/`vs'mean
			rename `v' `vn'
		}
		
		// Create 90/10 measures
		foreach t in priv_spb_tot priv_spb_ip medc_spb_tot medc_spb_ip {
			qui gen `t'_p90p10 = `t'_p90/`t'_p10
			drop `t'_p90 `t'_p10
		}
		
		
		
		qui gen i=.
		reshape long priv_spb_ip_ priv_spb_tot_ medc_spb_ip_ medc_spb_tot_, i(i) j(stat) s
		qui replace i = 1 if stat=="mean"
		qui replace i = 2 if stat=="sd"
		qui replace i = 3 if stat=="cov"
		qui replace i = 4 if stat=="p90p10"
		
		order i stat priv_spb* medc_spb* priv_corr* medc_corr*
		sort i
		list
		outsheet using HC_var_spb_table_`y'_bcbs`side'.csv, comma replace
		
		log close
	}	

}

exit
