if {[info commands try] eq ""} {
	package require try
}

proc nagios_exec {cmd} {
	## unnecessarily complicated command execution
	
	set output ""
	set code 0
	try {
		set fd [open "| $cmd"]
		set output [read $fd]
		close $fd
	} trap {CHILDSTATUS} {errmsg erropts} {
		# puts $::errorCode
		lassign $::errorCode - pid code
	} on error {errmsg erropts} {
		## e.g. command not found
		# puts "error: $errmsg"
		# puts "$::errorInfo"
		# puts "$::errorCode"
		# puts "$erropts"
		set code 3
		set output $errmsg
	}

	switch $code {
		0 {set status ok}
		1 {set status warning}
		2 {set status critical}
		3 {set status unknown}
	}

	set perfdata ""
	if {$code <= 2} {
		## parse output
		if {[regexp -- {(.*)\|(.*)} $output -> outdata perfdata]} {
			set output [string trimright $outdata]
			set perfdata [string trim $perfdata]
		}
	}

	return [list $code $status $output $perfdata]
}
