#!/usr/bin/env tclsh
package require Tcl 8.6
package require tcltest
# package require example
::tcltest::configure -testdir [file dirname [file normalize [info script]]]
::tcltest::configure {*}$::argv
::tcltest::runAllTests
