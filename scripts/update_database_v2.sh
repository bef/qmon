#!/bin/bash
sqlite3 ../db/qmon.db "ALTER TABLE checks ADD dependencies TEXT"
