source [file join [file dirname [info script]] ini-parser.tcl]

proc parse_config {fn} {
	array set cfg {
		global.plugin_path {}
		global.default_interval 3600
		checks {}
	}
	set default_check {
		host unknown
		desc ""
		enabled 1
		cmd {}
		interval ""
		type check
	}
	set default_host {
		desc ""
	}
	
	foreach {section kv} [::ini2::parse_file $fn] {
		if {$section ne "global"} {
			## no type? -> type=check
			if {![dict exists $kv type]} {
				dict set kv type check
			}
			
			switch [dict get $kv type] {
				host {
					## apply defaults
					set kv [dict merge $default_host $kv]
					
					## create empty check list for host
					if {![dict exists $cfg(checks) $section]} {dict set cfg(checks) $section {}}
				}

				check {
					## apply defaults
					set kv [dict merge $default_check $kv]
					if {[dict get $kv desc] eq ""} {dict set kv desc $section}
					if {[dict get $kv interval] eq ""} {dict set kv interval $cfg(global.default_interval)}
					
					## subst cmd
					dict set kv cmd [subst -nocommands [dict get $kv cmd]]
					
					## add check to list of checks by host
					dict lappend cfg(checks) [dict get $kv host] $section
				}
				default {return -code error "section $section's type is incorrect"}
			}
		}
		foreach {k v} $kv {
			set cfg(${section}.$k) $v
		}
		
	}

	##
	
	return [array get cfg]
}


