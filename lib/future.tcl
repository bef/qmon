## define Tcl8.6 function lmap
if {[info command lmap] eq ""} {
	proc lmap {varlist list body} {
		set i 0
		set varlist2 {}
		foreach var $varlist {
			upvar 1 $var var[incr i]
			lappend varlist2 var$i
		}
		set res {}
		foreach $varlist2 $list {lappend res [uplevel 1 $body]}
		set res
	}
}

