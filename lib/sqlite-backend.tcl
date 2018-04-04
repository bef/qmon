## see http://www.sqlite.org/tclsqlite.html
package require sqlite3

proc init_db {fn {readonly false}} {
	if {$readonly} {
		sqlite3 db $fn -create false -readonly true
	} else {
		sqlite3 db $fn -create true -readonly false
	}
}

proc create_db {} {
	db eval {
		CREATE TABLE IF NOT EXISTS checks (
			name TEXT PRIMARY KEY,
			cmd TEXT,
			interval NUMERIC,
			enabled INTEGER,
			host TEXT,
			desc TEXT,
			status TEXT,
			output TEXT,
			perfdata TEXT,
			last_check NUMERIC,
			interval_warning NUMERIC,
			interval_critical NUMERIC,
			interval_unknown NUMERIC,
			dependencies TEXT
		);
	}
}

proc update_check {args} {
	set columns {name cmd interval interval_warning interval_critical interval_unknown enabled host desc dependencies}
	foreach {k v} $args { set $k $v }

	if {[db exists {SELECT 1 FROM checks WHERE name = :name}]} {
		set setkv {}
		foreach c [lrange $columns 1 end] { lappend setkv "$c = :$c" }
		db eval "UPDATE checks SET [join $setkv ", "] WHERE name = :name"
	} else {
		set vlist [lmap v $columns {set _ ":$v"}]
		db eval "INSERT INTO checks ([join $columns ", "], status) VALUES ([join $vlist ", "], 'new')"
	}
}

proc all_checks_names {} {
	return [db eval {SELECT name FROM checks}]
}

proc delete_check {check} {
	db eval {DELETE FROM checks WHERE name = :check}
}

proc get_checks_for_execution {{force 0} {testlist {}}} {
	set sql {
		SELECT name, cmd, status, dependencies
			FROM checks
			WHERE enabled}
	if {!$force} {
		set timediff {(strftime('%s', 'now') - strftime('%s', last_check))}
		append sql " AND (last_check IS NULL "
		append sql "   OR (status = 'critical' AND $timediff >= interval_critical)"
		append sql "   OR (status = 'warning' AND $timediff >= interval_warning)"
		append sql "   OR (status = 'unknown' AND $timediff >= interval_unknown)"
		append sql "   OR (status <> 'critical' AND status <> 'warning' AND status <> 'unknown' AND $timediff >= interval)"
		append sql ")"
	}
	if {$testlist ne ""} {
		set i 0
		foreach testname $testlist {
			incr i
			lappend testlistsql "name = :testname_$i"
			set testname_$i $testname
		}
		append sql " AND ([join $testlistsql " OR "])"
	}

	## check dependencies
	set result [lmap {name cmd status dependencies} [db eval $sql] {
		set success 1
		foreach dep $dependencies {
			set result [db eval "SELECT 1 FROM checks WHERE name = :dep AND status = 'ok'"]
			if {$result ne "1"} {
				set success 0
				break
			}
		}
		if {!$success} { continue }
		list $name $cmd $status
	}]

	return [concat {*}$result]
}

proc update_result {check status output perfdata} {
	db eval {
		UPDATE checks
			SET status = :status, output = :output, perfdata = :perfdata, last_check = datetime('now')
			WHERE name = :check
	}
}

# proc get_status {} {
# 	return [db eval {
# 		SELECT name, cmd, interval, enabled, host, status output, perfdata, last_check
# 			FROM checks
# 			ORDER BY host, name
# 	}]
# }
# db close
