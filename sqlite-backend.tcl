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
			status TEXT,
			output TEXT,
			perfdata TEXT,
			last_check NUMERIC
		);
	}
}

proc update_check {check cmd interval enabled host} {
	if {[db exists {SELECT 1 FROM checks WHERE name = :check}]} {
		db eval {
			UPDATE checks
				SET cmd = :cmd, interval = :interval, enabled = :enabled, host = :host
				WHERE name = :check
		}
	} else {
		db eval {
			INSERT INTO checks (name, cmd, interval, enabled, host, status)
				VALUES (:check, :cmd, :interval, :enabled, :host, 'new')
		}
	}
}

proc all_checks_names {} {
	return [db eval {SELECT name FROM checks}]
}

proc delete_check {check} {
	db eval {DELETE FROM checks WHERE name = :check}
}

proc get_checks_for_execution {{force 0}} {
	set sql {
		SELECT name, cmd, status
			FROM checks
			WHERE enabled}
	if {!$force} {
		append sql { AND (last_check IS NULL OR strftime('%s', 'now') - strftime('%s', last_check) >= interval)}
	}
	return [db eval $sql]
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
