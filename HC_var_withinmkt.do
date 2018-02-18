/*------------------------------------------------------------------HC_var_withinmkt.do

Stuart Craig
Last updated 20151209
*/

timestamp, output
cap mkdir withinmkt
cap mkdir withinmkt/paper
cap mkdir withinmkt/web
foreach proc of global proclist {
	cap mkdir withinmkt/paper/`proc'
	cap mkdir withinmkt/web/`proc'
}


foreach proc of global proclist {
	if "`proc'"=="ip" continue
	use ${ddHC}/HC_epdata_hdata_`proc'.dta, clear
	
	loc procedure ""
	if "`proc'"=="hip" loc procedure "Hip Replacement"
	if "`proc'"=="knr" loc procedure "Knee Replacement"
	if "`proc'"=="delc" loc procedure "Cesarean Section"
	if "`proc'"=="delv" loc procedure "Vaginal Delivery"
	if "`proc'"=="ptca" loc procedure "PTCA"
	if "`proc'"=="col" loc procedure "Colonoscopy"
	if "`proc'"=="kmri" loc procedure "Lower Limb MRI"
	
	
	// Create the price measures
	cap drop raw_facprice
	cap drop raw_facmedprice
	cap drop adj_facprice
	cap drop adj_facmedprice
	qui gen adj_facprice	= adj_price
	qui gen adj_facmedprice	= medprice // no risk adj here
	if "`proc'"=="ip" qui replace adj_facmedprice = prov_pps
	cap gen raw_phyprice	= adj_plus_phy // won't happen for IP
	if _rc==0 pindex raw_phyprice, generate(adj_phyprice)
	
	foreach v of varlist /* raw_* */ adj_* {
		qui gen u_`v' = `v'
		qui gen p50_`v' = `v'
	}
	
	// Inflation adjust everything
	qui gen year = ep_adm_y
	cpigen
	qui summ cpi if year==2011
	qui replace cpi = cpi/r(mean)
	foreach v of varlist u_* p50* {
		qui replace `v' = `v'/cpi
	}
	
	collapse (mean) u_* (p50) p50_* (first) prov_hrr* [aw=prov_vol], by(prov_e_npi) fast
	
	// Save count list
	cap drop hcount
	qui egen hcount = count(prov_hrrnum), by(prov_hrrnum)
	keep if hcount>4 // exclusion up front
	preserve
		keep hcount prov_hrr*
		bys prov_hrrnum: keep if _n==1
		save withinmkt/temp_hrrcount_`proc'.dta, replace
	restore
	
	// Scaling parameters
	qui summ u_adj_facprice
	loc max = r(max)
	loc interval = round(`max'/4,1000)
	loc max = `interval'*4
	loc aint = `interval'
	loc amax = `max'

	// Just main HRRs with no titles
	foreach hrr of global hrrlist { // now we do all HRRs
		preserve
			keep if prov_hrrnum==`hrr'
			
			// pass the loop if it's a prohibitively small market
			qui count
			assert r(N)>4 // 5+ hospitals
			if _rc!=0 {
				restore
				continue
			}
		
			qui levelsof prov_hrrcity, loc(city)
			loc city = `city'
			qui levelsof prov_hrrstate, loc(st)
			loc st = `st'
		
			// Do it without titles (for the paper)
			qui summ u_adj_facmedprice, mean
			loc med = r(mean)
			qui summ u_adj_facprice
			loc priv = r(mean)
			loc mm = substr(string(r(max)/r(min)),1,4)
			loc cv = substr(string(r(sd)/r(mean)),1,4)
			if substr("`cv'",1,1)=="." loc cv = "0`cv'"
			cap drop g
			qui egen g = gini(u_adj_facprice)
			qui summ g, mean
			loc g = substr(string(r(mean)),1,4)
			if substr("`g'",1,1)=="." loc g = "0`g'"
			
			graph bar u_adj_facprice, over(prov_e_npi, sort(u_adj_facprice) label(nolabel)) stack ///
				title("  Max/Min Ratio: `mm'" "  Gini: `g'" "  CoV: `cv'", position(11) ring(0) size(vlarge)) legend(off) ///
				bar(1, bcolor("${red}"))  ytitle("") ///
				yline(`priv', lc("${red}") lstyle(solid) lw(medium)) ///
				ytitle("Price ($)", size(medlarge)) ylabel(0(`aint')`amax') 
			graph export  withinmkt/paper/`proc'/HC_var_withinmkt_`proc'_`=subinstr("`city'"," ","_",.)'_1.png, as(png) replace
			graph export  withinmkt/paper/`proc'/HC_var_withinmkt_`proc'_`=subinstr("`city'"," ","_",.)'_1.pdf, as(pdf) replace
			graph export  withinmkt/paper/`proc'/HC_var_withinmkt_`proc'_`=subinstr("`city'"," ","_",.)'_1.eps, as(eps) replace
			

		restore
	}
*/	
	// All HRRs with titles
	qui levelsof prov_hrrnum, local(hrrs)
	foreach hrr of local hrrs {
		preserve
			keep if prov_hrrnum==`hrr'
			
			// pass the loop if it's a prohibitively small market (should never happen anymore)
			qui count
			assert r(N)>4 // 5+ hospitals
			if _rc!=0 {
				restore
				continue
			}
		
			qui levelsof prov_hrrcity, loc(city)
			loc city = `city'
			qui levelsof prov_hrrstate, loc(st)
			loc st = `st'
			loc tag `"`=lower("`st'")'_`=lower(subinstr("`city'"," ","_",.))'"'
			di "`tag'"
		
		// All HRRs, med/nomed for the web
			qui summ u_adj_facmedprice, mean
			loc med = r(mean)
			qui summ u_adj_facprice
			loc priv = r(mean)
			loc mm = substr(string(r(max)/r(min)),1,4)
			loc cv = substr(string(r(sd)/r(mean)),1,4)
			if substr("`cv'",1,1)=="." loc cv = "0`cv'"
			cap drop g
			qui egen g = gini(u_adj_facprice)
			qui summ g, mean
			loc g = substr(string(r(mean)),1,4)
			if substr("`g'",1,1)=="." loc g = "0`g'"
			
			cap drop overmed
			qui gen overmed = u_adj_facprice - u_adj_facmedprice
			cap drop undermed
			qui gen undermed = u_adj_facprice if overmed<0
			qui replace u_adj_facmedprice = u_adj_facmedprice - undermed if overmed<0
			qui replace overmed=0 if overmed<0
			graph bar undermed u_adj_facmedprice overmed, over(prov_e_npi, sort(u_adj_facprice) label(nolabel)) stack ///
				title("{break}" "  Max/Min Ratio: `mm'" "  CoV: `cv'", position(11) ring(0) size(medsmall))  ///
				subtitle("Hospital Prices for `procedure'" "`city', `st', 2008-2011", position(12) ring(6) size(medlarge))  ytitle("") ///
				bar(1, color("${red}")) bar(2, color("${blu}")) bar(3, color("${red}")) ///
				yline(`priv', lc("${red}") lstyle(solid) lw(medium)) ///
				yline(`med', lc("${blu}") lstyle(solid) lw(medium)) ///
				ytitle("Price ($)", size(medlarge)) ylabel(0(`aint')`amax') xsize(20) ysize(20) ///
				legend(order(2 "Hospital's Medicare Payment Rate" 3 "Hospital's Negotiated Transaction Price") position(6) row(2) ring(6) size(small)) ///
				note("{bf:Note:} Each column captures a hospital’s negotiated transaction price and Medicare" ///
					 "reimbursement. Prices are averaged from 2008-2011 and presented in 2011 dollars. " ///
					 "CoV captures the coefficient of variation of hospital negotiated transaction prices within" ///
					 "the HRR. Max/Min captures the max/min ratio of hospital’s negotiated transaction prices" ///
					 "within the HRR. Horizontal lines indicate average rates and prices within the region." ///
					 "{break}" "{bf:{&copy} Health Care Pricing Project}", size(1.8) ring(12)) 
				
			graph export  withinmkt/web/`proc'/HC_var_withinmkt_`proc'_`tag'.png, as(png) replace
		restore
	
	
	}
	
}

// Create a spreadsheet of hospital counts by HRR to verify which graphs do/don't get produced
tempfile build
loc ctr=0
revlist "${proclist}"
foreach proc in `r(rev)' {
	if "`proc'"=="ip" continue
	loc ++ctr
	use withinmkt/temp_hrrcount_`proc'.dta, clear
	
	rename hcount `proc'_count
	if `ctr'>1 {
		cap drop _merge
		merge 1:1 prov_hrrnum using `build'
		drop _merge // keep it all either way
	}
	save `build', replace
}
outsheet using withinmkt/HC_var_withinmkt_hrrcounts.csv, comma replace


exit

