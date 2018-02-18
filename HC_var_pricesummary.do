/* ---------------------------------------------------HC_var_pricesummary.do
Creates all price summary graph

Stuart Craig
Last updated 20151209
*/

timestamp, output

	tempfile temptable
	loc ctr = 0
	foreach proc of global proclist {
		loc ctr = `ctr'+1
		
		use ${ddHC}/HC_epdata_hdata_`proc'.dta, clear
		
		// Prepare the price variables
		rename medprice medicare
		if "`proc'"=="ip" replace medicare = prov_pps
		cap drop paid
		qui gen paid = adj_price - medicare
		cap drop charge
		qui gen charge = adj_charge - adj_price // these are the marginal contributions of each
		
		// Adjust for inflation
		qui gen year=ep_adm_y
		cpigen
		qui summ cpi if year==2011
		qui replace cpi = cpi/r(mean)
		foreach v of varlist paid charge medicare adj_price adj_charge {
			qui replace `v' = `v'/cpi
		}
		
		collapse (mean) paid medicare charge adj_price adj_charge [aw=prov_vol], fast by(prov_e_npi)
		collapse (mean) paid medicare charge adj_price adj_charge, fast
		
		gen cohort = "`proc'"
		
		foreach v of varlist medicare paid charge adj_price adj_charge {
			qui replace `v' = round(`v')
		}
		
		* summ
		
		if `ctr'>1 append using `temptable'
		save `temptable', replace
	}
	cap drop *pct
	
	// Format numbers with commas
	foreach v in adj_charge adj_price medicare {
		loc n = subinstr("`v'", "adj_", "",.)
		gen str_`n' = string(`v')
		cap drop l
		gen l = strlen(str_`n')

		gen temph = substr(str_`n', -3, 3) //first hundred
		gen tempt = substr(str_`n', 1, 1) //thousand
		gen temptt = substr(str_`n', 1, 2) //ten thousand
		gen tempht = substr(str_`n', 1, 3) //ten thousand
	
		replace str_`n' = tempt+","+temph if l == 4 // number is single thousands	
		replace str_`n' = temptt+","+temph if l == 5 // number is ten thousands
		replace str_`n' = tempht+","+temph if l == 6 // number is hundred thousands (I don't think this ever the case, though)

		drop temp* l
	}
		
	// Build the bar labels
	qui gen chrg_pct = "$" + str_charge + " (" + string(round(100*(adj_charge/adj_price))) + "%)"
	qui gen paid_pct = "$" + str_price + " (100%)"
	qui gen medc_pct = "$" + str_med + " (" + string(round(100*(medicare/adj_price))) + "%)"
	/*
	foreach v of varlist *_pct {
		qui replace `v' = "" if inlist(cohort,"col","kmri","bmri")
	}
	*/
	
	drop str*
	
	cap drop order
	qui gen order = .
	loc ctr = 0
	foreach proc of global proclist {
		loc ctr = `ctr'+1
		
		loc pn ""
		if "`proc'"=="ip" loc pn "Inpatient"
		if "`proc'"=="hip" loc pn "Hip Replacement"
		if "`proc'"=="knr" loc pn "Knee Replacement"
		if "`proc'"=="delc" loc pn "Cesarean Delivery"
		if "`proc'"=="delv" loc pn "Vaginal Delivery"
		if "`proc'"=="lap" loc pn "Lap. Chole."
		if "`proc'"=="app" loc pn "Appendectomy"
		if "`proc'"=="cabg" loc pn "CABG"
		if "`proc'"=="ptca" loc pn "PTCA"
		if "`proc'"=="col" loc pn "Colonoscopy"
		if "`proc'"=="kmri" loc pn "Knee MRI"

		qui replace order = `ctr' if cohort=="`proc'"
		label define order `ctr' "`pn'", modify
	}
	label val order order
	
	qui gen labpos_charge 	= adj_charge
	qui gen labpos_price	= adj_price
	qui gen labpos_medicare	= medicare
	qui replace labpos_charge = 15000 if inlist(cohort,"kmri","col")
	qui replace labpos_price  = 13000 if inlist(cohort,"kmri","col")
	qui replace labpos_medicare   = 13800 if inlist(cohort,"kmri","col")
	
/*	tw 	bar medicare order, color("${blu}")	barw(.9) ///
	 || rbar adj_price medicare order, color("${red}") barw(.9)  ///
	 || rbar adj_charge adj_price order, color(gs11) barw(.9) xlabel(1/`=_N', noticks valuelabel angle(45) labsize(vsmall)) ///
		xtitle("") ytitle("") legend(order( 1 "Medicare" 2 "Negotiated Price" 3 "Charge") rows(1)) ylab(,labsize(small)) ///
	 || scatter labpos_charge order, ms(none) mla(chrg_pct) mlabpos(12) mlabgap(0) mlabcolor(black) mlabsize(vsmall) ///
	 || scatter labpos_price order, ms(none) mla(paid_pct) mlabpos(12) mlabgap(0) mlabcolor(black) mlabsize(vsmall) ///
	 || scatter labpos_medicare   order, ms(none) mla(medc_pct) mlabpos(6)  mlabgap(0) mlabcolor(black) mlabsize(vsmall) ///
	 aspect(.6) 
*/
	format medicare %12.0fc
	tw 	bar medicare order, color("$blu")	barw(.9) ///
	 || rbar adj_price medicare order, color("178 90 99") barw(.9)  ///
	 || rbar adj_charge adj_price order, lpattern(solid) color(gs14) barw(.9) lstyle(solid) lw(vvvthin) xlabel(1/`=_N', noticks valuelabel angle(45) labsize(vsmall)) ///
		xtitle("") ytitle("") legend(order( 1 "Medicare" 2 "Negotiated Price" 3 "Charge") rows(1)) ylab(,labsize(small)) ///
	 || scatter labpos_charge order, ms(none) mla(chrg_pct) mlabpos(12) mlabgap(0) mlabcolor(black) mlabsize(vsmall) ///
	 || scatter labpos_price order, ms(none) mla(paid_pct) mlabpos(12) mlabgap(0) mlabcolor(black) mlabsize(vsmall) ///
	 || scatter labpos_medicare   order, ms(none) mla(medc_pct) mlabpos(6)  mlabgap(0) mlabcolor(black) mlabsize(vsmall) ///
	 aspect(.6) 
	 
	graph export HC_var_pricesummary.png, as(png) replace
	graph export HC_var_pricesummary.eps, replace
	
	* outsheet using ${oHC}/HC_paper1_pricesummary.csv, comma replace



exit
