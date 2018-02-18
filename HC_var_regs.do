/* ----------------------------------------------------------------HC_var_regs.do
Creates all regressions and regression tables

Stuart Craig
Last updated 20151209
*/


timestamp, output
global date `r(date)'
cap mkdir regs
cd regs

/*
-------------------------------------------------
Running regressions
-------------------------------------------------
*/

* foreach proc of global proclist {
foreach proc in ip {
	use ${ddHC}/HC_epdata_hdata_`proc'.dta, clear		

	cap drop _merge
	pfixdrop merge
	qui gen merge_state = prov_hrrstate
	merge m:1 merge_state using ${ddHC}/HC_raw_statecoverage.dta
	assert _m>1 // for procedure samples we might not have all states but 
	drop if _m==2 //we should always be able to find coverage for your state if you're in the data
	drop _merge
	rename cov hcci_statecov
	
	
	cap drop _merge
	pfixdrop merge
	qui gen merge_county = prov_fips
	qui gen merge_year = ep_adm_y
	merge m:1 merge_county merge_year using ${ddHC}/HC_hccicoshare.dta
	assert _m>1
	drop if _m==2

	pfixdrop yeardum_
	pfixdrop dhrr_
	qui tab prov_hrrnum, gen(dhrr_)
	qui tab ep_adm_y, gen(yeardum_)


	// We only use risk adjusted prices
	cap rename adj_plusph adj_plusphy
	foreach lhs in price charge plusphy {
		cap drop `lhs'
		qui gen `lhs' = adj_`lhs'
	}

	/*
	-------------------------------------------------------------------------
	Creating tables (1 by 1)
	-------------------------------------------------------------------------
	*/	
		
	foreach lhs of varlist   price   charge plusphy  {
	//-------------------------------------------------- Main table
	cap mkdir ${oHC}/${date}/regs/`lhs'
	cd ${oHC}/${date}/regs/`lhs'
	cap log close
	log using HC_var_reg_`lhs'_`proc'.txt, text replace
		
		// Log/log
		eststo clear
		makex, log
		cap drop logprice
		qui gen logprice = log(1+`lhs')
		// Just hospital mkt structure
		eststo: reg logprice x_mdt* yeardum_*						, vce(cluster prov_hrrnum)
		// No insurance mkt structure
		drop x_inshhi
		eststo: reg logprice x_* yeardum_* 							, vce(cluster prov_hrrnum)
		eststo: reg logprice x_* yeardum_* dhrr_*					, vce(cluster prov_hrrnum)
		// Everything together
		makex, log hccishare 
		eststo: reg logprice x_* yeardum_* 							, vce(cluster prov_hrrnum)
		eststo: reg logprice x_* yeardum_* dhrr_*					, vce(cluster prov_hrrnum)
		
		esttab * using HC_paper1_reg_mainspec_`proc'_loglog.csv, replace nopa se r2 ///
			indicate("HRR FE = dhrr_*") drop(o.* _cons yeardum_*) scalars(N_clust F) ///
			star(* 0.10 ** 0.05 *** 0.01) b(%12.3f) se(%12.3f)
		
		// level/level
		eststo clear
		makex
		eststo clear
		// Just hospital mkt structure
		eststo: reg `lhs' x_mdt* yeardum_*						, vce(cluster prov_hrrnum)
		// No insurance mkt structure
		drop x_inshhi
		eststo: reg `lhs' x_* yeardum_* 						, vce(cluster prov_hrrnum)
		eststo: reg `lhs' x_* yeardum_* dhrr_*					, vce(cluster prov_hrrnum)
		// Everything together
		makex, hccishare 
		eststo: reg `lhs' x_* yeardum_* 						, vce(cluster prov_hrrnum)
		eststo: reg `lhs' x_* yeardum_* dhrr_*					, vce(cluster prov_hrrnum)
		
		esttab * using HC_paper1_reg_mainspec_`proc'_levellevel.csv, replace nopa se r2 ///
			indicate("HRR FE = dhrr_*") drop(o.* _cons yeardum_*) scalars(N_clust F) ///
			star(* 0.10 ** 0.05 *** 0.01) b(%12.1f) se(%12.1f)
		
		// log/level
		eststo clear
		makex
		cap drop logprice
		qui gen logprice = log(1+`lhs')
		// Just hospital mkt structure
		eststo: reg logprice x_mdt* yeardum_*						, vce(cluster prov_hrrnum)
		// No insurance mkt structure
		drop x_inshhi
		eststo: reg logprice x_* yeardum_* 							, vce(cluster prov_hrrnum)
		eststo: reg logprice x_* yeardum_* dhrr_*					, vce(cluster prov_hrrnum)
		// Everything together
		makex, hccishare 
		eststo: reg logprice x_* yeardum_* 							, vce(cluster prov_hrrnum)
		eststo: reg logprice x_* yeardum_* dhrr_*					, vce(cluster prov_hrrnum)
		
		esttab * using HC_paper1_reg_mainspec_`proc'_loglevel.csv, replace nopa se r2 ///
			indicate("HRR FE = dhrr_*") drop(o.* _cons yeardum_*) scalars(N_clust F) ///
			star(* 0.10 ** 0.05 *** 0.01) b(%12.3f) se(%12.3f)
		
		// level/log
		eststo clear
		makex, log
		eststo clear
		// Just hospital mkt structure
		eststo: reg `lhs' x_mdt* yeardum_*						, vce(cluster prov_hrrnum)
		// No insurance mkt structure
		drop x_inshhi
		eststo: reg `lhs' x_* yeardum_* 						, vce(cluster prov_hrrnum)
		eststo: reg `lhs' x_* yeardum_* dhrr_*					, vce(cluster prov_hrrnum)
		// Everything together
		makex, log hccishare 
		eststo: reg `lhs' x_* yeardum_* 						, vce(cluster prov_hrrnum)
		eststo: reg `lhs' x_* yeardum_* dhrr_*					, vce(cluster prov_hrrnum)
		
		esttab * using HC_paper1_reg_mainspec_`proc'_levellog.csv, replace nopa se r2 ///
			indicate("HRR FE = dhrr_*") drop(o.* _cons yeardum_*) scalars(N_clust F) ///
			star(* 0.10 ** 0.05 *** 0.01) b(%12.1f) se(%12.1f)
		
	
		
	/*
	------------------------------------------
	Robustness:

	Blue Cross Blue Shield
	- Q4 regress
	- Separate regression for Q1-4
	- Separate regression for p50 over/under

	Urban/Rural
	- Regression with Urban/Rural dummy
	- Separate regressions for Urban/Rural

	High low HCCI share
	- over .2 under .2
	------------------------------------------
	*/ 

		pfixdrop bcbsdum_
		qui tab cciio_q4bcbs, generate(bcbsdum_)
		eststo clear
		makex, log hccishare
		
		// 4 quartiles (pre-calculated) of BCBS coverage
		cap drop logprice
		qui gen logprice = log(1+`lhs')
		eststo: reg logprice bcbsdum_2 bcbsdum_3 bcbsdum_4 x_* yeardum_* dhrr_*		, vce(cluster prov_hrrnum)
		forvalues i=1/4 {
			cap drop priceq`i'
			qui gen priceq`i' = log(1+`lhs') if cciio_q4bcbs==`i'
			eststo: reg priceq`i' x_* yeardum_* dhrr_* 								, vce(cluster prov_hrrnum)
		}
		// Over/under 50th pctile of BCBS coverage
		cap drop p50under
		cap drop p50over
		qui gen p50under = log(1+`lhs') if cciio_q4bcbs<3
		qui gen p50over	 = log(1+`lhs') if cciio_q4bcbs>2
		eststo: reg p50under x_* yeardum_* dhrr_*  				, vce(cluster prov_hrrnum)
		eststo: reg p50over  x_* yeardum_* dhrr_* 				, vce(cluster prov_hrrnum)
		
		reg logprice cciio_bcbs_tot x_* yeardum_* dhrr_*		, vce(cluster prov_hrrnum)
		
		esttab * using HC_paper1_reg_bcbs_`proc'.csv, replace nopa se r2 ///
			indicate("HRR FE = dhrr_*") drop(o.* _cons yeardum_*) scalars(N_clust F) ///
			star(* 0.10 ** 0.05 *** 0.01) b(%12.3f) se(%12.3f)
			
		// Urban/rural split
		eststo clear
		makex, log hccishare
		cap drop prural
		cap drop purban
		cap drop logprice
		qui gen prural = log(1+`lhs') if mci_urgeo=="RURAL"
		qui gen purban = log(1+`lhs') if mci_urgeo!="RURAL"
		qui gen logprice = log(1+`lhs')
		eststo: reg prural x_* yeardum_* dhrr_*  				, vce(cluster prov_hrrnum)
		eststo: reg purban  x_* yeardum_* dhrr_* 				, vce(cluster prov_hrrnum)
		makex, log rural hccishare
		eststo: reg logprice  x_* yeardum_* dhrr_* 				, vce(cluster prov_hrrnum)
		
		esttab * using HC_paper1_reg_rural_`proc'.csv, replace nopa se r2 ///
			indicate("HRR FE = dhrr_*") drop(o.* _cons yeardum_*) scalars(N_clust F) ///
			star(* 0.10 ** 0.05 *** 0.01) b(%12.3f) se(%12.3f)
			
		// High/low HCCI share
		eststo clear
		makex, log
		cap drop hccihigh
		cap drop hccilow
		cap drop logprice
		qui gen hccihigh = log(1+`lhs') if hcci_statecov>=20
		qui gen hccilow	 = log(1+`lhs') if hcci_statecov<20
		qui gen logprice = log(1+`lhs')
		eststo: reg hccihigh x_* yeardum_* dhrr_*  				, vce(cluster prov_hrrnum)
		eststo: reg hccilow  x_* yeardum_* dhrr_* 				, vce(cluster prov_hrrnum)
		makex, log hccishare
		eststo: reg logprice  x_* yeardum_* dhrr_* 				, vce(cluster prov_hrrnum)
		
		esttab * using HC_paper1_reg_hcci_`proc'.csv, replace nopa se r2 ///
			indicate("HRR FE = dhrr_*") drop(o.* _cons yeardum_*) scalars(N_clust F) ///
			star(* 0.10 ** 0.05 *** 0.01) b(%12.3f) se(%12.3f)
			
		
		
	*/	
		
	//-------------------------------------------------- Competition table
		cap drop hhi_var
		qui gen hhi_var = .
		qui replace hhi_var = syshhi_20m if mci_urgeo=="RURAL"	
		qui replace hhi_var = syshhi_15m if mci_urgeo=="OURBAN"
		qui replace hhi_var = syshhi_10m if mci_urgeo=="LURBAN"
		
		eststo clear
		makex, log hccishare
		drop x_mdt_?
		
		// Loop over radii/measures
		foreach v of varlist syshhi_5m syshhi_15m syshhi_30m hhi_var hcount_15m {
			cap drop price_`v'
			qui gen price_`v' = log(1+`lhs')
			
			cap drop comp_measure
			qui gen comp_measure = log(1+`v') // LOG/LOG
			
			eststo: reg price_`v' comp_measure x_* dhrr_* yeardum_*, vce(cluster prov_hrrnum)
		}
		
		// Monopoly, duopoloy, triopoly dummies
		forvalues h=1/3 {
			cap drop comp_`h'
			qui gen comp_`h' = hcount_15m==`h'
		}
		cap drop logprice
		qui gen logprice = log(1+`lhs')
		eststo: reg logprice comp_? x_*  dhrr_* yeardum_*, vce(cluster prov_hrrnum)
		
		
		// What about competition quartiles
		cap drop Q4_hhi
		egen Q4_hhi = xtile(syshhi_15m), by(ep_adm_y) nq(4)
		forvalues q=2/4 {
			cap drop hhiq`q'
			qui gen hhiq`q' = Q4_hhi==`q'
		}
		eststo: reg logprice hhiq? x_* dhrr_* yeardum_*, vce(cluster prov_hrrnum)
		
		// Just Q4
		eststo: reg logprice hhiq4 x_* dhrr_* yeardum_*, vce(cluster prov_hrrnum)
		
		esttab * using HC_paper1_reg_comp_`proc'.csv, replace nopa se r2 ///
			indicate("HRR FE = dhrr_*") drop(o.* _cons yeardum_*) scalars(N_clust) ///
			star(* 0.10 ** 0.05 *** 0.01) b(%12.3f) se(%12.3f)

		
		
		
	//-------------------------------------------------- Summarize quality measures	
		
	// Normalize the mhc_ vars to all go the same direction
		preserve
			// Turn back these measures
			foreach v of varlist mhc_amim01 mhc_chfm03 mhc_pnem05   {
				qui replace `v' = 100-`v' // death rates are now survival rates
			}	
			foreach v of varlist mhc_* {
				gen mean_`v'=`v'
				gen sd_`v'=`v'
				gen N_`v' = `v'
				gen p25_`v' = `v'
				gen p75_`v' = `v'
			}
			collapse (mean) mean* (sd) sd* (count) N* (p25) p25* (p75) p75*, by(ep_adm_y) fast
			gen i=ep_adm_y
			reshape long mean_ sd_ N_ p25_ p75_, i(i) j(m) s
			
			sort m i
			outsheet using HC_paper1_summ_qual_`proc'.csv, comma replace
			
		restore	
	//-------------------------------------------------- Quality 1	
		
		eststo clear
		makex, log hccishare 
		drop x_usnews // we'll add it back in later
		
		cap gen pass = .
		foreach v of varlist pass usnwr_match  mhc_amim01 mhc_amim10 mhc_surgm08 mhc_surgm38 {
			
			
			cap drop logprice
			qui gen logprice = log(1+`lhs')
			if "`v'"=="pass" {
				preserve
					foreach q of varlist mhc_amim01 mhc_amim10 mhc_surgm08 mhc_surgm38 {
						drop if `q'==.|`q'<0
					}
					* drop if ep_adm_y!=2011 // keep it consistent
					eststo: reg logprice 			x_* dhrr_* yeardum_*, vce(cluster prov_hrrnum)
				restore
				continue
			}
			if "`v'"=="usnwr_match" {
				preserve
					foreach q of varlist mhc_amim01 mhc_amim10 mhc_surgm08 mhc_surgm38 {
						drop if `q'==.|`q'<0
					}
					* drop if ep_adm_y!=2011 // keep it consistent
					eststo: reg logprice usnwr_match x_* dhrr_* yeardum_*, vce(cluster prov_hrrnum)
				restore
				continue
			}
			
			// Take the bottom quartile
			preserve
				// We now do this so that all regressions have the same sample
				foreach q of varlist mhc_amim01 mhc_amim10 mhc_surgm08 mhc_surgm38 {
					drop if `q'==.|`q'<0
				}
				
				qui replace `v'=. if `v'<0
				drop if missing(`v') // |ep_adm_y!=2011
				
				cap drop temp
				cap drop qual_q1
				qui egen temp = xtile(`v'), nq(4) by(ep_adm_y)
				qui gen qual_q1 = temp==1
				
				loc suffix = subinstr("`v'","mhc_","",.)
				cap drop p_`suffix'
				qui gen p_`suffix' = log(1+`lhs')
				
				eststo: reg p_`suffix' qual_q1 usnwr_match x_* dhrr_* yeardum_*, vce(cluster prov_hrrnum)
				
			restore
			
		}
		preserve
			pfixdrop qual
			foreach v of varlist mhc_amim01 mhc_amim10 mhc_surgm08 mhc_surgm38 {
				qui replace `v'=. if `v'<0
				drop if missing(`v')
				
				cap drop temp
				cap drop qual_`v'
				qui egen temp = xtile(`v'), nq(4) by(ep_adm_y)
				qui gen qual_`v' = temp==1
			}	
			cap drop logprice
			qui gen logprice = log(1+`lhs')
			eststo: reg logprice qual* usnwr_match x_* dhrr_* yeardum_*, vce(cluster prov_hrrnum)
		restore

		esttab * using HC_paper1_reg_qual_q1_`proc'.csv, replace nopa se r2 ///
			indicate("HRR FE = dhrr_*") drop(o.*  _cons ) scalars(N_clust) ///
			star(* 0.10 ** 0.05 *** 0.01) b(%12.3f) se(%12.3f)

	log close
	}	
}


// Now, build the tables we care about:
cd ..
// 1. Main spec
	insheet using charge/HC_paper1_reg_mainspec_ip_loglog.csv, comma clear
	keep v1 v6 // with hccishare
	rename v6 charge
	gen n=_n
	tempfile charge
	save `charge', replace
	insheet using price/HC_paper1_reg_mainspec_ip_loglog.csv, comma clear
	gen n=_n
	merge 1:1 n using `charge'
	drop n _merge
	outsheet using HC_var_reg_mainspec_ip.csv, comma replace
// 1.1 Main spec no log
	insheet using charge/HC_paper1_reg_mainspec_ip_levellog.csv, comma clear
	keep v1 v6 // with hccishare
	rename v6 charge
	gen n=_n
	tempfile charge
	save `charge', replace
	insheet using price/HC_paper1_reg_mainspec_ip_levellog.csv, comma clear
	gen n=_n
	merge 1:1 n using `charge'
	drop n _merge
	outsheet using HC_var_reg_mainspec_ip_levellog.csv, comma replace
	
// 2. Quality
	insheet using price/HC_paper1_reg_qual_q1_ip.csv, comma clear
	outsheet using HC_var_reg_qual_q1_ip.csv, comma replace
// 3. Proc level regression	
	// Log/Log with FE
	loc ctr = 0
	tempfile build
	revlist "${proclist}"
	foreach proc in `r(rev)' {
		* if "`proc'"=="ip" continue
		loc ++ctr
		
		insheet using price/HC_paper1_reg_mainspec_`proc'_loglog.csv, comma clear
		gen n=_n
		
		rename v1 stat
		rename v6 `proc'
		keep n stat `proc'
		
		if `ctr'>1 {
			cap drop _merge
			merge 1:1 n using `build'
			assert _m==3
			drop _merge
		}
		save `build', replace
	}
	order n stat 
	outsheet using HC_var_reg_mainspec_allproc_fe.csv, comma replace
	
	// Log/Log without FE
	loc ctr = 0
	tempfile build
	revlist "${proclist}"
	foreach proc in `r(rev)' {
		* if "`proc'"=="ip" continue
		loc ++ctr
		
		insheet using price/HC_paper1_reg_mainspec_`proc'_loglog.csv, comma clear
		gen n=_n
		
		rename v1 stat
		rename v5 `proc'
		keep n stat `proc'
		
		if `ctr'>1 {
			cap drop _merge
			merge 1:1 n using `build'
			assert _m==3
			drop _merge
		}
		save `build', replace
	}
	order n stat 
	outsheet using HC_var_reg_mainspec_allproc_nofe.csv, comma replace
	
	// Log/Log with FE--plus physician prices
	loc ctr = 0
	tempfile build
	revlist "${proclist}"
	foreach proc in `r(rev)' {
		* if "`proc'"=="ip" continue
		loc ++ctr
		
		insheet using plusphy/HC_paper1_reg_mainspec_`proc'_loglog.csv, comma clear
		gen n=_n
	
		rename v1 stat
		rename v6 `proc'
		keep n stat `proc'
		
		if `ctr'>1 {
			cap drop _merge
			merge 1:1 n using `build'
			assert _m==3
			drop _merge
		}
		save `build', replace
	}
	order n stat 
	outsheet using HC_var_reg_mainspec_allproc_plusphy.csv, comma replace
	
// Comp 1	
	insheet using price/HC_paper1_reg_comp_ip.csv, comma clear
	outsheet using HC_var_reg_comp_ip.csv, comma replace
	
// Robustness tables
	insheet using price/HC_paper1_reg_bcbs_ip.csv, comma clear
	outsheet using HC_var_reg_bcbs_ip.csv, comma replace
	insheet using price/HC_paper1_reg_hcci_ip.csv, comma clear
	outsheet using HC_var_reg_hcci_ip.csv, comma replace
	insheet using price/HC_paper1_reg_rural_ip.csv, comma clear
	outsheet using HC_var_reg_rural_ip.csv, comma replace
	
	
exit






exit
