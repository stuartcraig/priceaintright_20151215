/*---------------------------------------------------------HC_var_provpatchar.do
Provider and patient characteristics
	
Stuart Craig
Last updated 	20151209
*/

timestamp, output

// Patient characteristics
foreach proc of global proclist {
	use ${ddHC}/HC_epdata_`proc'.dta, clear
	forvalues a=2/6 {
		qui gen age`a' = pat_age==`a'
	}
	rename pat_female female
	rename pat_charlson6 charlson
	bys prov_e_npi: gen prov_count=_n==1
	keep age? female charlson prov_count
	foreach v of varlist age? female charlson {
		qui gen mean_`v' 	= `v'
		qui gen sd_`v'		= `v'
		qui gen min_`v'		= `v'
		qui gen max_`v'		= `v'
	}
	qui gen pat_count=1
	collapse (mean) mean* (sd) sd* (min) min* (max) max* (sum) prov_count pat_count, fast
	tempfile pat
	save `pat', replace

// Provider characteristics
	use ${ddHC}/HC_epdata_hdata_`proc'.dta, clear
	
	cap drop _merge
	pfixdrop merge
	qui gen merge_county = prov_fips
	qui gen merge_year = ep_adm_y
	merge m:1 merge_county merge_year using ${ddHC}/HC_hccicoshare.dta
	assert _m>1
	drop if _m==2
	
	qui gen _01_mdt1		= hcount_15m==1
	qui gen _01_mdt2		= hcount_15m==2
	qui gen _01_mdt3		= hcount_15m==3
	qui gen _01hosphhi	= syshhi_15m
	qui gen _02inshhi  	= cciio_hhi_tot
	qui gen _03a_hccish = hcci_coshare
	qui gen _03b_bcbssh	= cciio_bcbs_tot
	qui gen _04tech	  	= aha_techtot
	qui gen _05usnews	= usnwr_match
	qui gen _06beds		= aha_hospbd
	qui gen _07teach	= aha_mapp5
	qui gen _08gov		= aha_c_g
	qui gen _09nonprofit= aha_c_np
	qui gen _10pctiu	= sahie_pctui/100
	qui gen _11medinc	= saipe_medinc
	qui gen _12rural	= mci_urgeo=="RURAL"
	qui gen _13pps		= prov_pps
	qui gen _14careshare= prop_care/100
	qui gen _15caidshare= prop_caid/100
	qui gen _16amideath = mhc_amim01/100  if mhc_amim01>0
	qui gen _17amiaspir = mhc_amim10/100  if mhc_amim10>0
	qui gen _18anti1hr	= mhc_surgm08/100 if mhc_surgm08>0
	qui gen _19clots24hr= mhc_surgm38/100 if mhc_surgm38>0 // these are scaled for regressions, but undo for excel table
	cap drop _merge
	foreach v of varlist _* {
		qui gen mean_`v' 	= `v'
		qui gen sd_`v'		= `v'
		qui gen min_`v'		= `v'
		qui gen max_`v'		= `v'
	}
	bys prov_e_npi: gen prov_count=_n==1
	collapse (mean) mean* (sd) sd* (min) min* (max) max* (sum) prov_count, fast
	merge 1:1 prov_count using `pat' // demand that the prov counts be the same
	assert _m==3
	drop _merge
	reshape long mean_ sd_ min_ max_, i(prov_count) j(v) s
	outsheet using HC_var_provpatchar_`proc'.csv, replace comma
}
exit
