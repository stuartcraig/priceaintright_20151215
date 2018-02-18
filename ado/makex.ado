/*--------------------------------------------------------------makex.ado

Stuart Craig
Last updated 20151209
*/

/*
-------------------------------------------------
Creates the set of x controls which we use in all
regressions. the [, log] option allows you to 
create the log/log spec x's (note that it 
DOES NOT log dummies). 
-------------------------------------------------
*/

cap prog drop makex
prog define makex
	syntax [, log] [hccishare] [rural] [bcbs]
	
	pfixdrop x_
	// Mkt structure
	* qui gen x_hsphhi = 		syshhi_15m
	forvalues h=1/3 {
		qui gen x_mdt_`h' = hcount_15m==`h'
	}
	* qui gen x_inshhi = 		naic_hhi
	qui gen x_inshhi = cciio_hhi_tot
	* if "`hccishare'"=="hccishare" qui gen x_inssh = inssh_prv*100
	if "`hccishare'"=="hccishare" qui gen x_inssh = hcci_coshare*100
	if "`bcbs'"=="bcbs" qui gen x_bcbs = cciio_bcbs_tot
	
	// H char
	qui gen x_tech  = 		aha_techtot
	qui gen x_usnews = 		usnwr_match
	qui gen x_beds = 		aha_hospbd
	qui gen x_teach = 		aha_mapp5
	qui gen x_gov = 		aha_c_g
	qui gen x_nonprofit = 	aha_c_np
	
	// Local area
	qui gen x_pctiu = 		sahie_pctui
	qui gen x_medinc = 		saipe_medinc
	if "`rural'"=="rural" qui gen x_rural = mci_urgeo=="RURAL"
	
	// Medicare/Medicaid
	qui gen x_ppspmt=		prov_pps
	qui gen x_medshare = 	prop_care
	qui gen x_caidshare = prop_caid
	
	
	if "`log'"!="" {
		foreach v of varlist x_* {
			cap assert inlist(`v',0,1) // we don't log the indicators
			if _rc==0 continue
			qui replace `v' = log(1+`v')
		}
	}
	
end
