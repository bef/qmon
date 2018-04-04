source [file join [file dirname [info script]] ini-parser.tcl]

proc parse_config {fn} {
	return [parse_config_data [::ini2::parse_file $fn]]
}

proc parse_config_string {str} {
	return [parse_config_data [::ini2::parse_string $str]]
}

proc parse_config_data {data} {
	array set cfg {
		global.plugin_path {}
		global.interval 3600
		global.interval_warning 1800
		global.interval_critical 600
		global.interval_unknown 1800
		checks {}
	}
	set default_check {
		host unknown
		desc ""
		enabled 1
		cmd {}
		interval "$cfg(global.interval)"
		interval_warning "$cfg(global.interval_warning)"
		interval_critical "$cfg(global.interval_critical)"
		interval_unknown "$cfg(global.interval_unknown)"
		type check
		dependencies {}
	}
	set default_host {
		desc ""
	}

	foreach {section kv} $data {
		set add_check_trigger 0

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

					## add check to check list of checks later (after subst)
					set add_check_trigger 1
				}

				default {return -code error "section $section's type is incorrect"}
			}
		}

		foreach {k v} $kv {
			if {[string index $v 0] eq "!"} {
				## no substitution for key=!value
				set cfg(${section}.$k) [string range $v 1 end]
				continue
			}
			## substitute all other values
			set cfg(${section}.$k) [subst -nocommands $v]
		}

		if {$add_check_trigger} {
			## create empty check list for host
			if {![dict exists $cfg(checks) $cfg(${section}.host)]} {dict set cfg(checks) $cfg(${section}.host) {}}

			## add check to list of checks by host
			dict lappend cfg(checks) $cfg(${section}.host) $section

			## convert dependencies to tcl list
			set cfg(${section}.dependencies) [lmap s [split $cfg(${section}.dependencies) ","] {string trim $s}]
		}

	}

	##

	return [array get cfg]
}
