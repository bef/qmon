package provide ini2 0.1
package require fileutil

namespace eval ::ini2 {}

proc ::ini2::parse_file {fn} {
	set lines [split [fileutil::cat $fn] "\n"]
	set lines [macroprocessor $lines]
	return [parse_ini $lines]
}

## substitute templates
proc ::ini2::macroprocessor {lines} {
	array set tmpl {}
	array set tmpl_argumentnames {}
	set usecnt 1
	while {$usecnt} {
		## $mode is "out" or "tmpl". both array variables must exist
		set mode out
		
		## $out is the list of output lines for each iteration
		set out {}
		
		## $usecnt is how many templates were substituted in each iteration
		set usecnt 0
		foreach line $lines {
			if {[regexp {^#template\s+(.*?)(?:\s+(.*))?$} $line -> template_name arguments]} {
				set mode tmpl($template_name)
				set tmpl($template_name) {}
				set tmpl_argumentnames($template_name) $arguments
				continue
			}
			if {[regexp {^#end\s+template\s*$} $line]} {
				set mode out
				continue
			}
			if {$mode eq "out" && [regexp {^#use\s+(.*?)(?:\s+(.*))?$} $line -> template_name arguments]} {
				incr usecnt
				## apply template
				if {![info exists tmpl($template_name)]} {return -code error "unknown template '$template_name'"}
				set mapping [lmap argname $tmpl_argumentnames($template_name) arg $arguments {list $argname $arg}]
				set mapping [concat {*}$mapping]
				foreach l $tmpl($template_name) {
					lappend out [string map $mapping $l]
				}
				continue
			}
			lappend $mode $line
		}
		if {$usecnt} {set lines $out}
	}
	return $out
}

## this is more or less what package inifile would have done.
proc ::ini2::parse_ini {lines} {
	set section "global"
	set out {}
	foreach line $lines {
		## ignore comments and empty lines
		if {[regexp {^\s*;} $line] || [regexp {^\s*$} $line]} {continue}
		
		## parse sections
		if {[regexp {^\[(.*?)\]\s*} $line -> section]} {
			dict set out $section {}
			continue
		}
		
		## parse key/value pairs
		regexp {^(.*?)(?:=(.*))?$} $line -> key value
		dict lappend out $section $key $value
	}
	return $out
}

# foreach {section kv} [::ini2::parse_file [file dirname [info script]]/../x/initest.ini] {
# 	puts "\n\[$section\]"
# 	foreach {k v} $kv {
# 		puts "$k=$v"
# 	}
# }
