/*--------------------------------------------------------HC_var_chargecompare.do

Stuart Craig
Last updated 20151209
*/

timestamp, output

foreach proc of global proclist {

	use ${ddHC}/HC_epdata_hdata_`proc'.dta, clear

	// Adjust for inflation
	gen year = ep_adm_y
	cpigen
	qui summ cpi if year==2011, mean
	qui replace cpi = cpi/r(mean)
	foreach v of varlist adj_price adj_charge {
		qui replace `v' = `v'/cpi
	}
	
	collapse (mean) adj_price adj_charge [aw=prov_vol], by(prov_e_npi) fast
	
	qui reg adj_price adj_charge
	loc r = "0" + substr(string(sqrt(e(r2))),1,4)
	loc b = "0" + substr(string(_b[adj_charge]),1,4)
	
	foreach v of varlist adj_price adj_charge {
		qui replace `v' = round(`v')
		format `v' %12.0fc
	}
	qui replace adj_price = round(adj_price)
	qui replace adj_charge = round(adj_charge)
	compress
	
	tw scatter adj_price adj_charge, msize(medsmall) msymbol(circle) ///
		|| lfit adj_price adj_charge, lw(thick) ///
		title("Correlation: `r'", size(medlarge)) ///
		xtitle("Chargemaster Price") ytitle("Negotiated Price") legend(off) 
		 
	graph export HC_var_chargeprice_`proc'.png, as(png) replace
	graph export HC_var_chargeprice_`proc'.eps, as(eps) replace
	
}
