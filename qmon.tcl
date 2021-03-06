#!/usr/bin/env tclsh
##
## quick monitoring script
##   BeF <bef@pentaphase.de> - 2014-01-15
##

package require Tcl 8.5

set qmondir [file dirname [info script]]
if {[info exists env(QMON)]} {set qmondir $env(QMON)}

set qmon_version "0.1dev3"

## parse command line arguments
package require cmdline
set options [list \
	[list ini.arg "${qmondir}/etc/qmon.ini" "configuration file"] \
	[list db.arg "${qmondir}/db/qmon.db" "sqlite db"] \
	[list lib.arg "${qmondir}/lib" "lib directory"] \
	{t "test mode. print checks, but do not execute. only relevant for cmd 'check'"} \
	{f "force check now. only relevant for cmd 'check'"} \
	{nc "no color output. for 'status'"} \
	{v "verbose output"} \
	]
set usage "v$::qmon_version - by Ben Fuhrmannek <bef@pentaphase.de>
  https://github.com/bef/qmon\n
$::argv0 \[options] <cmd>

COMMANDS:
showconfig : show parsed configuration
             this can be used to check the configuration for syntax errors.

    update : commit changes from ini to database

     check : actually perform the check. this command should be used in a crontab

    status : print out current status

OPTIONS:"

if {[catch {
	array set params [::cmdline::getoptions argv $options $usage]
} err]} {
	puts $err
	exit 1
}

source [file join $params(lib) future.tcl]
source [file join $params(lib) nagios-parser.tcl]
source [file join $params(lib) config-parser.tcl]
source [file join $params(lib) sqlite-backend.tcl]

## get config
array set ::cfg [parse_config $params(ini)]
# parray cfg

switch -glob -- [lindex $argv 0] {
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
				set update_args [list name $check]
				foreach k {cmd interval interval_warning interval_critical interval_unknown enabled host desc dependencies} {
					lappend update_args $k $::cfg(${check}.$k)
				}
				update_check {*}$update_args
			}
		}

		db close
	}

	check {
		set testlist [lrange $argv 1 end]
		init_db $params(db)
		foreach {name cmd status} [get_checks_for_execution $params(f) $testlist] {
			if {[string index $cmd 0] ne "/"} {
				set cmd1 [lindex [split $cmd " "] 0]

				foreach path $::cfg(global.plugin_path) {
					if {[file executable "$path/$cmd1"] && ![file isdirectory "$path/$cmd1"]} {
						set cmd "$path/$cmd"
						break
					}
				}
			}
			if {$params(t) || $params(v)} {
				## test mode.
				puts "$name: $cmd"
				if {$params(t)} {continue}
			}

			set ret [nagios_exec $cmd]
			lassign $ret code status2 output perfdata
			if {$params(v)} {
				puts "$name: \[$status2\] $output | $perfdata"
			}
			update_result $name $status2 $output $perfdata

			if {$status ne $status2 && [info exists cfg(global.notify_cmd)]} {
				set cmd [lmap arg $cfg(global.notify_cmd) {subst $arg}]
				if {[catch {exec {*}$cmd} err]} {puts stderr "ERROR in cmd for $name:\n$err"}
			}

		}
		db close
	}

	status {
		array set color {ok "" warning "" critical "" unknown "" new "" default ""}
		if {!$params(nc)} {
			## color output
			package require term::ansi::code::ctrl
			namespace import ::term::ansi::code::ctrl::sda_*
			array set color [list ok [sda_fggreen] warning [sda_fgyellow] critical [sda_fgred] unknown [sda_fgcyan] new [sda_fgwhite] default [sda_fgdefault]]
		}
		init_db $params(db)
		db eval {SELECT * FROM checks WHERE enabled ORDER BY host, name} c {
			set cstart [expr {[info exists color($c(status))] ? $color($c(status)) : ""}]
			set cend $color(default)
			puts [format "* \[${cstart}%7s${cend}] %-30s %s" $c(status) "$c(host)/$c(name)" $c(last_check)]
			puts "$c(output) | $c(perfdata)"
		}
		db close
	}

	jsonstatus {
		package require json::write
		set result {}
		init_db $params(db)
		db eval {SELECT * FROM checks WHERE enabled ORDER BY host, name} c {
			set entry {}
			foreach k $c(*) {
				set v [json::write string $c($k)]
				lappend entry $k $v
			}
			lappend result [json::write object {*}$entry]
		}
		db close
		puts [json::write array {*}$result]
	}

	default {
		puts "? :(\ntry $::argv0 -h"
		exit 1
	}
}
