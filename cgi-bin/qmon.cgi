#!/usr/bin/env tclsh8.6

package require ncgi
package require html
interp alias {} he {} ::html::html_entities

##

proc statuslabel {status} {
	switch $status {
		ok {return success}
		warning {return warning}
		critical {return danger}
		unknown {return info}
		new -
		default {return default}
	}
}

##

if {[info exists env(QMON)]} {
	set qmondir $env(QMON)
} elseif [info exists env(SCRIPT_FILENAME)] {
	set qmondir [file join [file dirname $env(SCRIPT_FILENAME)] ..]
} else {
	set qmondir [file join [file dirname $::argv0] ..]
}

# source [file join $qmondir config-parser.tcl]
source [file join $qmondir lib sqlite-backend.tcl]

## get config
# set qmon_ini [file join $qmondir qmon.ini]
# if {[info exists env(QMON_INI)]} {set qmon_ini $env(QMON_INI)}
# array set ::cfg [parse_config $qmon_ini]

## db
set qmon_db [file join $qmondir db qmon.db]
if {[info exists env(QMON_DB)]} {set qmon_db $env(QMON_DB)}
if {![file readable $qmon_db]} {puts "DB not readable: $qmon_db"; exit 1}
init_db $qmon_db true

##

::ncgi::header {text/html; charset=utf-8} {*}{Cache-Control "no-store,no-cache,max-age=0,must-revalidate"
Expires "Thu, 01 Dec 1994 16:00:00 GMT"
Pragma "no-cache"
"X-Content-Type-Options" nosniff
"X-DNS-Prefetch-Control" off
"X-Frame-Options" sameorigin
"X-XSS-Protection" "1; mode=block"}

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
      <h1>QMON Status</h1>
      <p class="lead">Service Detail</p>
    </div>
}]

puts {<div class="panel panel-default">
  <div class="panel-body">
}

set statuscount [db eval {SELECT status, COUNT(*) AS cnt FROM checks WHERE enabled GROUP BY status;}]
foreach status {ok warning critical unknown new} {
	set cnt 0
	if {[dict exists $statuscount $status]} {
		set cnt [dict get $statuscount $status]
	}
	set statuslabel default
	if {$cnt} {
		set statuslabel [statuslabel $status]
	}
	puts [subst {<span class="label label-${statuslabel}">$status: $cnt</span></td>}]
}

puts {
	 </div>
</div>
}

puts {
	<table class="table">
	<tr><th>Host</th><th>Status</th><th>Description</th><th>Last Check</th><th>Interval</th><th>Output</th></tr>
}
db eval {SELECT * FROM checks WHERE enabled ORDER BY host, name} c {
	set statuslabel [statuslabel $c(status)]
	puts [subst {
		<tr>
		<td>[he $c(host)]</td>
		<td><span class="label label-${statuslabel}">[he $c(status)]</span></td>
		<td>[he $c(desc)]</td>
		<td>[he $c(last_check)]</td>
		<td>[he $c(interval)]s</td>
		<td>[he $c(output)]</td>
		</tr>
	}]
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

db close
