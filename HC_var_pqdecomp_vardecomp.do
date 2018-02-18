/* ------------------------------------------------------------HC_var_pqdecomp_vardecomp.do

Stuart Craig
Last updated 20151209
*/

timestamp, output
cap mkdir pqdecomp
cd pqdecomp

/*
-----------------------------------------------------

First, prepare extracts for the variance
decomp. In particular, we need HRR level
price and quantity for every DRG, for both
private and public payers

-----------------------------------------------------
*/


	cap confirm file ${tHC}/decomp2_private.dta
	if _rc!=0 {

		loc decompyear = "2011"
		
		use ${ddHC}/HC_var_pqdecomp_ip.dta, clear
		keep if inrange(year(fst_admtdt),2008,2011) // should already be done
		if "`decompyear'"!="all" keep if year(fst_admtdt)==`decompyear'
		
		keep if price>0
		qui gen vol=1
		collapse (mean) price (sum) vol, by(drg hrrnum) fast
		rename price 	hrr_price
		rename vol 		hrr_vol
		
		// Bring in the HRR membership numbers
		cap drop _merge
		
		pfixdrop merge
		qui gen merge_year 	= "`decompyear'"
		qui gen merge_hrr 	= hrrnum
		merge m:1 merge_hrr  merge_year  using ${ddHC}/HC_var_pqdecomp_prvenroll.dta
		qui drop if _m==2
		drop _merge
		
		* replace hrr_vol = hrr_vol/enrollee
		gen double vol = hrr_vol/enrollee
		gen double price = hrr_price
		gen double totspend = hrr_vol*hrr_price
		* rename hrr_price price
		* rename hrr_vol vol
		drop hrr_*
		
		reshape wide price vol totspend, i(hrrnum) j(drg) s
		
		foreach v of varlist vol* price* {
			qui replace `v' = 0 if `v'==.
		}
		*/
		save ${tHC}/decomp2_private.dta, replace
	}

	cap confirm file ${tHC}/decomp2_public.dta
	if _rc!=0 {
		loc decompyear "2011"

		use ${ddHC}/HC_externaldata_ahd_nedata.dta, clear
		keep if inrange(year,2008,2011) // match years in HCCI
		if "`decompyear'"!="all" keep if year==`decompyear'
		//drgtotalpayment is price var
		
		// Bring in HRRs
		pfixdrop merge
		cap drop _merge
		qui gen merge_zip = substr(ziphcris,1,5)
		qui gen merge_year = year
		merge m:1 merge_zip merge_year using ${ddHC}/HC_externaldata_atlas_zipcrosswalk.dta
		keep if _m==3
		
		collapse (sum) drgtotalpayment drgcases, by(hrrnum drgnum) fast
		cap drop price 
		qui gen double price  	= drgtotalpayment/drgcases
		qui gen double vol 		= drgcases
		qui gen double totspend = drgtotalpayment

		gen drg = string(drgnum)
		qui replace drg = "0" + drg if length(drg)<3
		
		pfixdrop merge
		qui gen merge_year="`decompyear'" // comes from the loop!
		qui gen merge_hrr = hrrnum
		cap drop _merge
		merge m:1 merge_hrr merge_year using ${ddHC}/HC_var_pqdecomp_medbene.dta
		drop if _m==2
		drop _merge
		rename atlas_Bh enrollee
		
		qui replace vol = vol/enrollee
		
		drop drgnumber drgtotalpayment drgcases
		reshape wide price vol totspend, i(hrrnum) j(drg) s
		
		foreach v of varlist vol* price* {
			qui replace `v' = 0 if `v'==.
		}
		save ${tHC}/decomp2_public.dta, replace
	}

	
/*
-----------------------------------------------------

Run the full decomposition--one public one private

NOTE: this is the most efficient way to do this. For a
more readable version is available below the -exit- 
statement. 

-----------------------------------------------------
*/
	foreach t in private public {
		clear all
		set maxvar 10000
		use ${tHC}/decomp2_`t'.dta, clear

		cap drop v_spending
		qui gen v_spending=0
		foreach pricevar of varlist price* {
			loc volvar = subinstr("`pricevar'","price","vol",.)
			loc num = subinstr("`pricevar'","price","",.)
			
			qui summ `pricevar' if `pricevar'>0
			loc pmin = r(min)
			qui summ `volvar' if `volvar'>0
			loc vmin = r(min)
			qui gen v_lnp`num' = ln(`pricevar' + `pmin')
			qui gen v_lnq`num' = ln(`volvar' + `vmin')
			qui gen v_lnpq`num' = ln((`pricevar' + `pmin')*(`volvar' + `vmin'))
			qui gen v_pq`num' = `pricevar'*`volvar'
			qui corr v_lnq`num' v_lnp`num', c
			qui gen cov2_`num'=r(cov_12)*2
			qui gen count`num' = `volvar'*enrollee
			qui replace v_spending = v_spending + v_pq`num'
		}
		collapse (sd) v_* (first) cov2_* (sum) count* totspend*, fast
		gen i=.
		reshape long v_lnp v_lnq v_lnpq v_pq cov2_ count totspend, i(i) j(drg) s
		foreach v of varlist v_* {
			qui replace `v' = `v'^2 // transform to variance
		}

		qui gen share_p 	= v_lnp/v_lnpq
		qui gen share_q 	= v_lnq/v_lnpq
		qui gen share_cov 	= cov2_/v_lnpq

		// Save a dataset of the DRG-level decomp
		outsheet using HC_var_pqdecomp_drglevel_`t'.csv, comma replace
		save ${tHC}/HC_var_pqdecomp_drglevel_`t'.dta, replace

		// Add up the components of the larger data and make a table
		// (this is the big decomp referenced in the footnote)
		* preserve
		qui gen contribution_p = (v_lnp/v_lnpq)*v_pq
		qui gen contribution_q = (v_lnq/v_lnpq)*v_pq
		qui gen contribution_c = (cov2_/v_lnpq)*v_pq
		collapse (sum) contribution* (first) v_spending, fast
		foreach v of varlist contribution* {
			qui replace `v' = `v'/v_spending
		}
		gen contribution_C = 1 - contribution_p - contribution_q - contribution_c
		reshape long contribution_, i(v_spending) j(type) s
		list
		outsheet using HC_var_pqdecomp_aggregate_`t'.csv, comma replace
		* restore

	}	
*/	

/*
--------------------------------------------

Create a big table: 
Get 25 biggest DRG's, present averages 
across DRGs

--------------------------------------------
*/

	use ${tHC}/HC_var_pqdecomp_drglevel_private.dta, clear
	gen private=1
	append using ${tHC}/HC_var_pqdecomp_drglevel_public.dta
	replace private=0 if private==.
	bys drg: gen N=_N
	tab N
	drop if N==1
	bys private (totspend): gen rank = _N+1-_n
	egen averagerank = mean(rank), by(drg)


	// Merge on the DRG descriptions
	qui gen msdrg=drg
	merge m:1 msdrg using ${ddHC}/HC_externaldata_cms_drgcrosswalk.dta, keepusing(msdrg_description) 
	drop if _m==2
	drop _merge

	sort averagerank drg private
	list drg msdrg_description share* v_pq count private totspend in 1/100

	// Big the biggest of the set we care about:
	* drop if inlist(drg,"885","945","897") // drop psych stuff (in the top 20ish, there's obviously more psych stuff)
	drop if inrange(real(drg),876,897)


	gen simple=1
	foreach v of varlist simple totspend v_pq count {
		preserve
			collapse (mean) share* [aw=`v'], by(private) fast
			qui gen msdrg_description = "Average Shares"
			tempfile agg
			save `agg', replace
		restore
		preserve
			keep in 1/50 // top 25
			append using `agg'
			sort private averagerank drg
			keep share* *drg* private
			reshape wide share_p share_q share_cov, i(msdrg_description) j(private)
			outsheet using HC_var_pqdecomp_aggsharetable_`v'weight.csv, comma replace
		restore
	}
	// Also produce a full list for the online appendix
	preserve
		collapse (mean) share* [aw=totspend], by(private) fast
		qui gen msdrg_description0 = "Average Shares"
		tempfile agg
		save `agg', replace
	restore
	sort private averagerank drg
	keep share* *drg* private
	reshape wide share_p share_q share_cov msdrg_description, i(msdrg) j(private)
	append using `agg'
	outsheet using HC_var_pqdecomp_aggsharetable_all.csv, comma replace
	
exit
