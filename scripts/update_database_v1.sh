#!/bin/bash
sqlite3 ../db/qmon.db "ALTER TABLE checks ADD interval_warning NUMERIC"
sqlite3 ../db/qmon.db "ALTER TABLE checks ADD interval_critical NUMERIC"
sqlite3 ../db/qmon.db "ALTER TABLE checks ADD interval_unknown NUMERIC"
