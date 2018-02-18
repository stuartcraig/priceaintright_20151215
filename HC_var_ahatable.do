/*------------------------------------------------------------HC_var_ahatable.do

Stuart Craig
Last updated 20151209
*/

foreach proc of global proclist {	
	// First, set up the AHA data, including the Saidin and derived vars
		use ${ddHC}/HC_externaldata_aha_mdata, clear // this is the pared down version (no critical access)
		keep if inrange(merge_year,2008,2011)
		keep if inlist(aha_serv,10,13,42,44,47)
		
		cap drop aha_c_p
		cap drop aha_c_np
		qui gen aha_c_p=inrange(aha_cntrl,31,33)
		qui gen aha_c_np = inlist(aha_cntrl,21,23)
		qui gen aha_c_g = !aha_c_p&!aha_c_np
		drop aha_c_p // private becomes the reference category
		
		// Payer shares
		cap drop prop_caid
		cap drop prop_care
		qui gen prop_caid = aha_mcddc/aha_admtot*100
		qui gen prop_care = aha_mcrdc/aha_admtot*100
	
		//Mkt structure and tech
		cap drop _merge
		merge 1:1 merge_year merge_npi using ${ddHC}/HC_externaldata_aha_mkt_s_beds.dta, ///
			keepusing(syshhi_15m syshhi_10m syshhi_20m syshhi_5m syshhi_30m)
		drop if _m==2
		
		cap drop _merge
		merge 1:1 merge_year merge_npi using ${ddHC}/HC_externaldata_aha_mkt_h_beds.dta, ///
			keepusing(hcount_15m)
		drop if _m==2
	
		cap drop _merge
		merge 1:1 merge_year merge_npi using ${ddHC}/HC_externaldata_aha_techtot.dta
		drop if _m==2
	/*	We now do this at the county level
		cap drop _merge
		merge 1:1 merge_year merge_npi using ${ddHC}/HC_externaldata_aha_inssh.dta
		drop if _m==2
	*/	
	
	// Bring in insurer HHIs
		cap drop _merge
		cap drop merge_state
		qui gen merge_state = aha_mstate
		merge m:1 merge_state using ${ddHC}/HC_externaldata_cciio_statehhis.dta, ///
			keepusing(cciio_hhi* *bcbs*)
		drop if _m==2
		drop _merge
		
		cap drop _merge
		cap drop merge_state
		qui gen merge_state = aha_mstate
		merge m:1 merge_state merge_year using ${ddHC}/HC_externaldata_naic.dta
		drop if _m==2
		drop _merge
	
	// HCCI share
		cap drop _merge
		qui gen merge_county = string(aha_fcounty)
		qui replace merge_county = "0" + merge_county if length(merge_county)<5
		qui replace merge_county = "0" + merge_county if length(merge_county)<5
		qui replace merge_county = "0" + merge_county if length(merge_county)<5
		qui replace merge_county = "0" + merge_county if length(merge_county)<5
		qui replace merge_county = "0" + merge_county if length(merge_county)<5
		merge m:1 merge_county merge_year using ${ddHC}/HC_hccicoshare.dta
		drop if _m==2
		qui replace hcci_coshare = 0 if _m==1 // if we couldn't calculate one for you, there's no one there
	// USNWR
		cap drop _merge
		merge 1:1 merge_npi merge_year using ${ddHC}/HC_externaldata_usnwr_coll.dta
		drop if _m==2
		qui gen usnwr_match = _m==3

	// SAHIE
		cap drop merge_county
		qui gen merge_county = string(aha_fcounty)
		qui replace merge_county = "0"+merge_county if length(merge_county)<5
		qui replace merge_county = "0"+merge_county if length(merge_county)<5
		qui replace merge_county = "0"+merge_county if length(merge_county)<5
		qui replace merge_county = "0"+merge_county if length(merge_county)<5
		qui replace merge_county = "0"+merge_county if length(merge_county)<5
		cap drop _merge
		merge m:1 merge_county merge_year using ${ddHC}/HC_externaldata_census_sahie.dta
		drop if _m==2
		drop _merge

	// SAIPE
	rename merge_county merge_fips
	merge m:1 merge_fips merge_year using ${ddHC}/HC_externaldata_census_saipe.dta
	drop if _m==2
	drop _merge
	
// Quality
	merge m:1 merge_npi merge_year using ${ddHC}/HC_externaldata_mhc.dta, ///
	keepusing(mhc_amim01 mhc_amim10 mhc_surgm08  mhc_surgm38)
	drop if _m==2
	drop _merge

// Hospital revenue
	cap drop _merge
	merge 1:1 merge_npi merge_year using ${ddHC}/HC_externaldata_cms_mci.dta
	drop if _m==2 // we need wage and capital	
	rename mci_pps_pmt prov_pps
	
	makex, hccishare bcbs rural
	qui gen x_q1 = mhc_amim01 
	qui gen x_q2 = mhc_amim10 
	qui gen x_q3 = mhc_surgm08 
	qui gen x_q4 = mhc_surgm38
	qui gen x_hosphhi = syshhi_15m

	foreach v of varlist x_* {
		loc vn = subinstr("`v'","x_","a_",.)
		rename `v' `vn'
	}

	// Identify which of the 2 are in our sample
	cap drop _merge
	merge 1:1 merge_year merge_npi using ${ddHC}/HC_epdata_hdata_`proc'.dta, keepusing(prov_e_npi ep_adm_y)
	drop if _m==2
	
	makex, hccishare bcbs rural
	qui gen x_q1 = mhc_amim01 
	qui gen x_q2 = mhc_amim10 
	qui gen x_q3 = mhc_surgm08 
	qui gen x_q4 = mhc_surgm38
	qui gen x_hosphhi = syshhi_15m
	foreach v of varlist x_* {
		qui replace `v'=. if _m==1
	}
	
	// Keep the most recent year (that's a match)
	bys merge_npi (_merge merge_year): keep if _n==_N
	qui gen acount=1
	qui gen xcount=1 if _m==3
	
	collapse (mean) a_* x_* (count) *count , fast
	
	qui gen i=.
	reshape long a x, i(i) j(stat) string
	
	qui replace stat = subinstr(stat,"_","",.)
	qui replace i = 1.0 if stat=="mdt1"
	qui replace i = 1.1 if stat=="mdt2"
	qui replace i = 1.2 if stat=="mdt3"
	qui replace i = 1.3 if stat=="hosphhi"
	qui replace i = 2 if stat=="inshhi"
	qui replace i = 3 if stat=="bcbs"
	qui replace i = 4 if stat=="tech"
	qui replace i = 5 if stat=="usnews"
	qui replace i = 6 if stat=="beds"
	qui replace i = 7 if stat=="teach"
	qui replace i = 8 if stat=="gov"
	qui replace i = 9 if stat=="nonprofit"
	qui replace i = 10 if stat=="pctiu"
	qui replace i = 11 if stat=="medinc"
	qui replace i = 12 if stat=="rural"
	qui replace i = 13 if stat=="ppspmt"
	qui replace i = 14 if stat=="medshare"
	qui replace i = 15 if stat=="caidshare"
	qui replace i = 16 if stat=="q1"
	qui replace i = 17 if stat=="q2"
	qui replace i = 18 if stat=="q3"
	qui replace i = 19 if stat=="q4"
	qui replace i = 20 if stat=="count"
	
	* drop if stat=="count"
	sort i stat
		
	outsheet using HC_paper1_ahatable_`proc'.csv, comma replace
}	

tempfile build	
loc ctr=0
revlist "${proclist}"
foreach proc in `r(rev)' {
	loc ++ctr
	insheet using HC_paper1_ahatable_`proc'.csv, comma clear
	rename x `proc'
	
	if `ctr'>1 {
		cap drop _merge
		merge 1:1 stat using `build'
		assert _m==3
		drop _merge
	}
	save `build', replace
	rename a aha
}
sort i 
outsheet using HC_paper1_ahatable.csv, comma replace

exit
