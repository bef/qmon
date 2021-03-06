#!/bin/bash
case $1 in
	ok)
	echo "OK"
	exit 0
	;;
	
	warning)
	echo "WARNING"
	exit 1
	;;
	
	critical)
	echo "CRITICAL"
	exit 2
	;;
	
	unknown)
	echo "UNKNOWN"
	exit 3
	;;
	
	perfdata)
	echo "OK | foo:13 bar:14"
	exit 0
	;;
esac