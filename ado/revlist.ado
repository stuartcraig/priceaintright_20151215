


cap prog drop revlist
prog define revlist, rclass
	args l_in

	loc l2 ""
	foreach word in `l_in' {
		loc l2 "`word' `l2'"
	}

	return local rev = "`l2'"

end


exit
