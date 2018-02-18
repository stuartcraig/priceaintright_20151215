/*---------------------------------------------------------------------HC_var.do
All analysis files for the variation project
	
Stuart Craig
Last updated 	20151012
*/

// Aggregates--total spending and membership
	do ${scHC}/HC_var_totspending.do

// Provider/patient characteristics
	do ${scHC}/HC_var_provpatchar.do 

// Correlation of prices across clinical cohorts
	do ${scHC}/HC_var_pricecorr.do

// Price/quantity decomposition(s)
	do ${scHC}/HC_var_pqdecomp.do

// Data for GIS maps
	do ${scHC}/HC_pricemaps.do

// Mean and CoV price for top 25 biggest HRRs
	do ${scHC}/HC_var_summtop25.do

// All regressions and table builds
	do ${scHC}/HC_var_regs.do

// Price summary figure
	do ${scHC}/HC_var_pricesummary.do

// Create SPB measures and analysis
	do ${scHC}/HC_var_spb_riskadj.do
	do ${scHC}/HC_var_spb_ranks.do
	do ${scHC}/HC_var_spb_highlow.do

// Bivariate correlation table/figure
	do ${scHC}/HC_var_bivariatecorr.do

// Within market graphs
	do ${scHC}/HC_var_withinmkt.do

// AHA comparison table
	do ${scHC}/HC_var_ahatable.do

// AHA technologies table
	do ${scHC}/HC_var_techtable.do

// Charge/price scatter plots
	do ${scHC}/HC_var_chargecompare.do

// National variation figure
	do ${scHC}/HC_var_natvar.do

exit
