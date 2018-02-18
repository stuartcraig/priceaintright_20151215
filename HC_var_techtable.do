/*--------------------------------------------------------------HC_var_techtable.do
Creates descriptive table of technologies in the AHA

Stuart Craig
Last updated 20151209
*/

timestamp, output


/*
------------------------------------------------

First, prepare an extract of the candidate 
technologies

------------------------------------------------
*/

	use ${ddHC}/HC_externaldata_aha_edata.dta, clear
	keep if inrange(year,2008,2011)
	keep *hos year e_npi

	// Drop a handfull of variables which represent characteristics rather than
	// services or technologies
	drop ipahos gpwwhos ophohos cphohos msohos ismhos eqmodhos foundhos phyhos ///
		iphmohos ipppohos ipfeehos
	// Drop a handfull of unknowns
	drop gamnhos angiohos cardhos cclabhos ohsrghos tplnthos reprohos

	tempfile techlist
	save `techlist', replace
/*
	qui egen techtotal = rowtotal(*hos)
	rename year merge_year
	rename e_npi merge_npi
	rename techtotal aha_techtot
	save ${ddHC}/HC_externaldata_aha_techtot.dta, replace
*/
	
/*
------------------------------------------------

Next, claculate the number of years for which 
years there are at least some valid values

------------------------------------------------
*/

	use `techlist', clear
	collapse (max) *hos, by(year) fast

	gen i=.
	reshape wide *hos, i(i) j(year)

	foreach v of varlist *2008 *2009 *2010 *2011 {
		loc y = substr("`v'",-4,4)
		loc vn = subinstr("`v'","`y'","",.)
		rename `v' y`y'`vn'
	}

	reshape long y2008 y2009 y2010 y2011, i(i) j(var) s

	tempfile yearlist
	save `yearlist'



/*
------------------------------------------------

Create a set of "sample means"--over our data

------------------------------------------------
*/


	use `techlist', clear
	
	qui gen prov_e_npi = e_npi
	qui gen ep_adm_y = year
	cap drop _merge
	merge 1:1 prov_e_npi ep_adm_y using ${ddHC}/HC_epdata_hdata_ip.dta
	drop if _m<3 // only 1s
	
	collapse *hos, fast
	foreach v of varlist *hos {
		rename `v' v_`v'
	}
	gen i=.
	reshape long v_, i(i) j(var) s

	tempfile meanlist
	save `meanlist', replace

/*
------------------------------------------------

Create a set of variable names and build
the final table

------------------------------------------------
*/

	use `techlist', clear
	d, replace clear
	rename name 	var
	rename varlab 	descrip
	keep var descrip

	// Bring in the year data and means
	cap drop _merge
	merge 1:1 var using `yearlist'
	* assert _m!=2
	drop _merge

	cap drop _merge
	merge 1:1 var using `meanlist'
	* assert _m!=2
	drop _merge

	// Final clean up and output the table
	drop if inlist(var,"year","e_npi")
	drop i
	qui replace descrip = subinstr(descrip," - hospital","",.)
	qui replace descrip = trim(descrip)
	outsheet using HC_var_techtable.csv, comma replace


exit
