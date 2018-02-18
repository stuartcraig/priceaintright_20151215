/* ---------------------------------------------------------------------------HC_var_pqdecomp.do

Stuart Craig
Last updated 20151209
*/

timestamp, output


// Create the datasets to be used--enrollment, cleaned inpatient file

	do ${scHC}/HC_var_pqdecomp_dataprep.do


// Run pfix/vfix counterfactuals

	do ${scHC}/HC_var_pqdecomp_counterfactuals.do

	
// Create the true variance decomposition

	do ${scHC}/HC_var_pqdecomp_vardecomp.do

	

	
	
exit
