/*---------------------------------------------------------HC_var_bivariatecorr.do

Stuart Craig
20151017
*/
timestamp, output

// Correlates
use ${ddHC}/HC_epdata_hdata_ip.dta, clear

cap drop _merge
pfixdrop merge
qui gen merge_county = prov_fips
qui gen merge_year = ep_adm_y
merge m:1 merge_county merge_year using ${ddHC}/HC_hccicoshare.dta
assert _m>1
drop if _m==2

cap drop e_price
qui summ adj_price
qui gen e_price = (adj_price - r(mean))/r(sd)

makex, rural hccishare
*drop x_mdt* 
*qui gen x_hosphhi = syshhi_15m
* drop x_inssh

pfixdrop x_qual
qui gen x_qual1=mhc_amim10 
qui gen x_qual2=mhc_surgm08
qui gen x_qual3=mhc_surgm38
qui gen x_qual4=mhc_amim01
foreach v of varlist x_qual? {
	qui replace `v' = . if `v'<0
	cap drop temp
	qui egen temp = xtile(`v'), nq(4) by(ep_adm_y)
	qui replace `v' = temp==1
}

loc ctr=0
foreach v of varlist x_* {
	loc ++ctr
	loc stub = subinstr("`v'","x_","",.)
	
	cap drop e_x
	qui summ `v'
	qui gen e_x = (`v'-r(mean))/r(sd)
	qui reg e_price e_x

	qui gen mu_`stub' 	= _b[e_x]
	qui gen cih_`stub'	= _b[e_x] + 1.96*_se[e_x]
	qui gen cil_`stub'	= _b[e_x] - 1.96*_se[e_x]
	qui gen pos_`stub'	= `ctr'
}
keep mu* ci* pos*
keep if _n==1
gen i=.
reshape long mu_ cih_ cil_ pos_, i(i) j(x) s


// Make the scatterplot
qui summ pos, d
qui replace pos = r(max)-pos
sort pos
list

qui replace pos = pos+1 if pos>3
qui replace pos = pos+1 if pos>7
qui replace pos = pos+1 if pos>11
qui replace pos = pos+1 if pos>18
list

expand 2
bys pos: gen n=_n
sort pos n
qui replace cih_ = cil_ if n==1
drop cil_

#d ;
label define x
	24 	"Hospital in Monopoly Market, 15m"
	23 	"Hospital in Duopoly Market, 15m"	
	22	"Hospital in Triopoly Market, 15m"
	21	"Insurer HHI: Covered Lives, State"
	20 	"HCCI Share of Lives Covered, County"
	19 	""
	18 	"Number of Technologies"
	17 	"Ranked by US News and World Reports"
	16 	"Number of Beds"
	15 	"Teaching"
	14	"Government"
	13	"Non-Profit"
	12	""
	11	"Percent of County Uninsured"
	10	"County Median Income"
	9	"Rural"
	8	""
	7 	"Medicare Base Payment"
	6 	"Medicare Share of Patients"
	5 	"Medicaid Share of Patients"
	4	""
	3	"Worst Quartile: % AMI Patients Given Aspirin at Arrival"
	2	"Worst Quartile: % Patients Given Antibiotic 1 Hr Pre-Surgery"
	1	"Worst Quartile: % of Surgery Patients Treated to Prevent Blood Clots"
	0	"Worst Quartile: 30-day AMI Survival Rate", replace;
label val pos x;
#d cr

tw	line pos cih_ if pos==0, lc("${blu}") || 	scatter pos mu  if pos==0, msymbol(circle) mc("${red}") || ///
	line pos cih_ if pos==1, lc("${blu}") || 	scatter pos mu  if pos==1, msymbol(circle) mc("${red}") || ///
	line pos cih_ if pos==2, lc("${blu}") || 	scatter pos mu  if pos==2, msymbol(circle) mc("${red}") || ///
	line pos cih_ if pos==3, lc("${blu}") || 	scatter pos mu  if pos==3, msymbol(circle) mc("${red}") || ///
	line pos cih_ if pos==5, lc("${blu}") || 	scatter pos mu  if pos==5, msymbol(circle) mc("${red}") || ///
	line pos cih_ if pos==6, lc("${blu}") || 	scatter pos mu  if pos==6, msymbol(circle) mc("${red}") || ///
	line pos cih_ if pos==7, lc("${blu}") || 	scatter pos mu  if pos==7, msymbol(circle) mc("${red}") || ///
	line pos cih_ if pos==9, lc("${blu}") || 	scatter pos mu  if pos==9, msymbol(circle) mc("${red}") || ///
	line pos cih_ if pos==10, lc("${blu}") || 	scatter pos mu  if pos==10, msymbol(circle) mc("${red}") || ///
	line pos cih_ if pos==11, lc("${blu}") ||	scatter pos mu  if pos==11, msymbol(circle) mc("${red}") || ///
	line pos cih_ if pos==13, lc("${blu}") ||	scatter pos mu  if pos==13, msymbol(circle) mc("${red}") || ///
	line pos cih_ if pos==14, lc("${blu}") ||	scatter pos mu  if pos==14, msymbol(circle) mc("${red}") || ///
	line pos cih_ if pos==15, lc("${blu}") ||	scatter pos mu  if pos==15, msymbol(circle) mc("${red}") || ///
	line pos cih_ if pos==16, lc("${blu}") ||	scatter pos mu  if pos==16, msymbol(circle) mc("${red}") || ///
	line pos cih_ if pos==17, lc("${blu}") ||	scatter pos mu  if pos==17, msymbol(circle) mc("${red}") || ///
	line pos cih_ if pos==18, lc("${blu}") ||	scatter pos mu  if pos==18, msymbol(circle) mc("${red}") || ///
	line pos cih_ if pos==20, lc("${blu}") ||	scatter pos mu  if pos==20, msymbol(circle) mc("${red}") || ///
	line pos cih_ if pos==21, lc("${blu}") ||	scatter pos mu  if pos==21, msymbol(circle) mc("${red}") || ///
	line pos cih_ if pos==22, lc("${blu}") ||	scatter pos mu  if pos==22, msymbol(circle) mc("${red}") || ///
	line pos cih_ if pos==23, lc("${blu}") ||	scatter pos mu  if pos==23, msymbol(circle) mc("${red}") || ///
	line pos cih_ if pos==24, lc("${blu}") ||	scatter pos mu  if pos==24, msymbol(circle) mc("${red}") ///
	legend(off)  ///
	ylab(0 1 2 3 5 6 7 9 10 11 13 14 15 16 17 18 20 21 22 23 24, valuelabel labsize(small)) ytitle("") xtitle("{&rho}") ///
	yline(4, lc(black)) yline(8, lc(black)) yline(12, lc(black)) yline(19, lc(black)) ///
	xlab(-.4(.2).4, labsize(small)) xline(0, lc(black) lstyle(solid)) xsize(2) ysize(1.2)
	
graph export HC_paper1_bivariatecorr.png, as(png) replace
graph export HC_paper1_bivariatecorr.eps, as(eps) replace

exit
