package require inifile

proc parse_config {fn} {
	array set cfg {global.plugin_path {} global.default_interval 3600 checks {}}
	set default_check {host unknown desc "" enabled 1 cmd {} interval "" type check}
	set default_host {desc ""}
	
	set ini [::ini::open $fn r]
	foreach s [::ini::sections $ini] {
		set sdict [::ini::get $ini $s]
		if {$s ne "global"} {
			if {![dict exists $sdict type]} {
				dict set sdict type check
				# return -code error "section '$s' has no type"
			}
			if {[info exists cfg(${s}.type)]} {return -code error "duplicate section '$s'"}
			switch [dict get $sdict type] {
				host {
					set sdict [dict merge $default_host $sdict]
					if {![dict exists $cfg(checks) $s]} {dict set cfg(checks) $s {}}
				}
				check {
					set sdict [dict merge $default_check $sdict]
					if {[dict get $sdict desc] eq ""} {dict set sdict desc $s}
					set h [dict get $sdict host]
					# if {![dict exists $cfg(checks) $h]} {dict set cfg(checks) $h {}}
					dict lappend cfg(checks) $h $s
				}
				default {return -code error "section '$s' has unknown type"}
			}
			# lappend cfg([dict get $sdict type]s) $s
		}
		foreach {k v} $sdict {
			set cfg(${s}.$k) $v
		}
	}
	::ini::close $ini
	
	##
	
	foreach {host checks} $cfg(checks) {
		foreach check $checks {
			## subst commands
			set cmd $cfg(${check}.cmd)
			set cfg(${check}.cmd) [subst -nocommands $cmd]
	
			## set default values
			if {$cfg(${check}.interval) eq ""} {set cfg(${check}.interval) $cfg(global.default_interval)}
			
		}
	}
	
	##
	
	return [array get cfg]
}

# puts [parse_config qmon.ini]

