#!/usr/bin/env tclsh8.6

package require ncgi
::ncgi::header {text/html; charset=utf-8} {*}{Cache-Control "no-store,no-cache,max-age=0,must-revalidate"
Expires "Thu, 01 Dec 1994 16:00:00 GMT"
Pragma "no-cache"
"X-Content-Type-Options" nosniff
"X-DNS-Prefetch-Control" off
"X-Frame-Options" sameorigin
"X-XSS-Protection" "1; mode=block"}

##

if {[info exists env(QMON)]} {
	set libdir $env(QMON)
} elseif [info exists env(SCRIPT_FILENAME)] {
	set libdir [file join [file dirname $env(SCRIPT_FILENAME)] ..]
} else {
	set libdir [file join [file dirname $::argv0] ..]
}

source [file join $libdir config-parser.tcl]
source [file join $libdir sqlite-backend.tcl]

## get config
set qmon_ini [file join $libdir qmon.ini]
if {[info exists env(QMON_INI)]} {set qmon_ini $env(QMON_INI)}
array set ::cfg [parse_config $qmon_ini]

## db
set qmon_db [file join $libdir db qmon.db]
if {[info exists env(QMON_DB)]} {set qmon_db $env(QMON_DB)}
if {![file readable $qmon_db]} {puts "DB not readable: $qmon_db"; exit 1}
init_db $qmon_db true

##

puts [subst {<!DOCTYPE html>
<html>
  <head>
    <title>QMON Status</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link href="/qmon/css/bootstrap.min.css" rel="stylesheet">

    <!-- HTML5 Shim and Respond.js IE8 support of HTML5 elements and media queries -->
    <!-- WARNING: Respond.js doesn't work if you view the page via file:// -->
    <!--\[if lt IE 9]>
      <script src="https://oss.maxcdn.com/libs/html5shiv/3.7.0/html5shiv.js"></script>
      <script src="https://oss.maxcdn.com/libs/respond.js/1.3.0/respond.min.js"></script>
    <!\[endif]-->
  </head>
  <body>
  <div class="container">

    <div class="starter-template">
      <h1>Status</h1>
      <p class="lead">TPS Report</p>
    </div>
}]


# puts $libdir
# puts foo.
# parray env

puts {
	<table class="table">
	<tr><th>Host</th><th>Status</th><th>Description</th><th>Last Check</th><th>Interval</th><th>Output</th></tr>
}
db eval {SELECT * FROM checks WHERE enabled ORDER BY host, name} c {
	# puts "-------------$c(name)"
	switch $c(status) {
		ok {set statuslabel success}
		warning {set statuslabel warning}
		critical {set statuslabel danger}
		unknown -
		default {set statuslabel default}
	}
	puts [subst {
		<tr>
		<td>$c(host)</td>
		<td><span class="label label-${statuslabel}">$c(status)</span></td>
		<td>$c(desc)</td>
		<td>$c(last_check)</td>
		<td>$c(interval)s</td>
		<td>$c(output)</td>
		</tr>
	}]
	# puts $c(enabled)
	# puts "</td><td>"
	# puts "$c(status)"
	# puts "</td><td>"
	# puts "$c(name)"
	# puts "</td><td>"
	# puts "$c(cmd)"
	# puts "</td><td>"
	# puts "$c(interval)"
	# puts "</td><td>"
	# puts "$c(last_check)"
	# puts "</td><td>"
	# puts "$c(output)"
	# puts "</td><td>"
	# puts "$c(perfdata)"
	# puts "</td><td>"
	# puts [format "\[%7s] %-30s %s" $c(status) "$c(host)/$c(name)" $c(last_check)]
	# puts "$c(output) | $c(perfdata)"
	# puts "</tr>"
}
puts {</table>}


puts [subst {
  </div><!-- /.container -->
  

    <!-- jQuery (necessary for Bootstrap's JavaScript plugins) -->
    <script src="/qmon/js/jquery-2.0.3.min.js"></script>
    <!-- Include all compiled plugins (below), or include individual files as needed -->
    <script src="/qmon/js/bootstrap.min.js"></script>
  </body>
</html>}]

##


##

db close
