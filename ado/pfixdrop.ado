/*----------------------------------------------------------------------pfixdrop.ado
This program quickly drops variables with a common prefix taken in as an arg

Stuart Craig
Last updated 1/28/15
*/


// Program to drop a set of vars based on prefix, but won't
// break if they don't exist

	cap program drop pfixdrop
	prog define pfixdrop
		args p
		
		cap d `p'*
		if _rc==0 drop `p'*
		
	end

	
exit
