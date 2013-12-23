#!/usr/bin/env tclsh8.6

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

# puts [nagios_exec "./test.sh warning"]
# puts "----- nicht existent"
# puts [nagios_exec "foo bar"]
# 
# foreach i {ok warning critical unknown} {
# 	puts "----- $i"
# 	puts [nagios_exec "./test.sh $i"]
# }

# puts [nagios_exec " /usr/lib/nagios/plugins/check_smtp -H mail.sektioneins.de -4 -v"]
# puts [nagios_exec "/usr/lib/nagios/plugins/check_http -H localhost -v -u http://devvm/x.html"]

## errors: invalid cmd, exit code, stderr output, too slow (timeout), too much output
# fileevent?
