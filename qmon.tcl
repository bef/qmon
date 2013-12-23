#!/usr/bin/env tclsh8.6
##
## quick monitoring script
##   BeF <bef@pentaphase.de> - 2014-01-15
##

set qmondir [file dirname [info script]]
if {[info exists env(QMON)]} {set qmondir $env(QMON)}

set qmon_version "0.1dev"

## parse command line arguments
package require cmdline
set options [list \
	[list ini.arg "${qmondir}/etc/qmon.ini" "configuration file"] \
	[list db.arg "${qmondir}/db/qmon.db" "sqlite db"] \
	[list lib.arg "${qmondir}/lib" "lib directory"] \
	{t "test mode. print checks, but do not execute. only relevant for cmd 'check'"} \
	{f "force check now. only relevant for cmd 'check'"} \
	]
set usage "v$::qmon_version - by BeF <bef@pentaphase.de>\n$::argv0 \[options] <showconfig|update|check|status>\noptions:"
if {[catch {
	array set params [::cmdline::getoptions argv $options $usage]
} err]} {
	puts $err
	exit 1
}

source [file join $params(lib) nagios-parser.tcl]
source [file join $params(lib) config-parser.tcl]
source [file join $params(lib) sqlite-backend.tcl]

## get config
array set ::cfg [parse_config $params(ini)]
# parray cfg

switch -glob -- $argv {
	showconfig {
		puts "-------"
		puts "qmon: $::qmon_version"
		puts "Tcl: $::tcl_version"
		puts "-------"
		foreach {k v} [array get cfg "global.*"] {
			puts "$k: $v"
		}
		puts "-------"
		foreach {host checks} $cfg(checks) {
			puts "HOST: $host"
			foreach {k v} [array get cfg "$host.*"] {
				puts "|  $k: $v"
			}
			foreach check $checks {
				puts "++ CHECK: $check"
				foreach {k v} [array get cfg "$check.*"] {
					puts "  |  $k: $v"
				}
			}
		}
	}
	
	update {
		init_db $params(db)
		create_db
		
		## delete checks from db which are not in cfg
		foreach check [all_checks_names] {
			if {[info exists cfg(${check}.type)]} {
				if {$cfg(${check}.type) eq "check"} {continue}
			}
			delete_check $check
		}
		
		## create/update all other checks
		foreach {host checks} $cfg(checks) {
			foreach check $checks {
				update_check $check $::cfg(${check}.cmd) $::cfg(${check}.interval) $::cfg(${check}.enabled) $::cfg(${check}.host) $::cfg(${check}.desc)
			}
		}
		
		db close
	}
	
	check {
		init_db $params(db)
		foreach {name cmd status} [get_checks_for_execution $params(f)] {
			if {[string index $cmd 0] ne "/"} {
				set cmd1 [lindex [split $cmd " "] 0]
			
				foreach path $::cfg(global.plugin_path) {
					if {[file executable "$path/$cmd1"] && ![file isdirectory "$path/$cmd1"]} {
						set cmd "$path/$cmd"
						break
					}
				}
			}
			if {$params(t)} {
				## test mode.
				puts "$name: $cmd"
				continue
			}
			
			set ret [nagios_exec $cmd]
			lassign $ret code status2 output perfdata
			update_result $name $status2 $output $perfdata
			
			if {$status ne $status2 && [info exists cfg(global.notify_cmd)]} {
				set cmd [lmap arg $cfg(global.notify_cmd) {subst $arg}]
				if {[catch {exec {*}$cmd} err]} {puts stderr "ERROR in cmd for $name:\n$err"}
			}
			
		}
		db close
	}
	
	status {
		init_db $params(db)
		db eval {SELECT * FROM checks ORDER BY host, name} c {
			puts [format "\[%7s] %-30s %s" $c(status) "$c(host)/$c(name)" $c(last_check)]
			puts "$c(output) | $c(perfdata)"
		}
		db close
	}
	
	default {
		puts "? :(\ntry $::argv0 -h"
		exit 1
	}
}

