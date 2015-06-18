#!/bin/echo "to be read with 'source' -- not for stand-alone use"
# =============================================================================
# Extended Remote Trace-Debugging for Tcl Examples
# =============================================================================
# This file is the part that needs to be included into the application. 
#
# The configuration section below is technically a Tcl dict. At the outer level
# the severities are defined. For each severity there may be an
# - action with one of the values[*1]
#   - die     (fatality, end exection after the GUI part is informed)
#   - show    (show the message in the GUI part and continue)
#   - ignore  (do NOT inform the GUI part about these severity)
#   - inspect (stop and allow interactive inspection)
# - hide with one of the values
#   - false   (default is to show that severity)
#   - true    (default is NOT to show that severity)
# - colors with the value
#   - background/foreground color for message in GUI (separated by slash)
#
# [*1]: Note that the default if no action is set is to ignore that severity.

# -----------------------------------------------------------------------------
#                                                         Configuration Section
set debugRemoteGUI 127.0.0.1:55669
set debugMessages {
    FATAL {
        action die
        colors violet/white
    }
    ERROR {
        action show
        colors red/white
    }
    WARNING {
        action show
        colors orange/black
    }
    INFO {
        action show
        colors yellow/black
    }
    TRACE {
        action ignore
        hide true
        colors lightgreen/black
    }
    STOP {
        action inspect
        hide true
        colors black/white
    }
}

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#             USUALLY NOTHING NEEDS TO BE CHANGED BELOW THAT LINE

set debugNextAttempt [clock seconds]

# -----------------------------------------------------------------------------
#                                   Print Severity and Message (and maybe exit)
#
proc dbg {severity message} {
    if {![dict exists $::debugMessages $severity]\
     || ![dict exists $::debugMessages $severity action]} return
    set action [dict get $::debugMessages $severity action]
    switch -exact -- $action {
        ignore return
    }
    if {![dbg_setup_channel]} return
    set level [info level]
    if {$level == 1} {
        set caller $::argv0
    } else {
        set caller [lindex [info level [expr {$level-1}]] 0]
    }
    if {[catch {
        puts $::debugChannel "\[$severity] $caller: $message"
        flush $::debugChannel
    }]} {
        catch {close $::debugChannel}
        unset ::debugChannel
    }
    switch -exact -- $action {
        die {exit 127 }
    }
    if {![info exists ::debugChannel]} return
    switch -exact -- $action {
        inspect {
            if {[catch {
                while {[gets $::debugChannel cmd] > 0} {
                    if {[catch [list uplevel $cmd] result]} {
                        puts $::debugChannel "! $result"
                    } else {
                        puts $::debugChannel "= $result"
                    }
                    flush $::debugChannel
                }
            } bigproblem]} {
                catch {
                    puts $::debugChannel "? $bigproblem"
                    close $::debugChannel
                }
                unset -nocomplain $::debugChannel
            }
        }
    }
}

proc dbg_setup_channel {} {
    if {[info exists ::debugChannel]} {
        return 1
    }
    set now [clock seconds]
    if {$now < $::debugNextAttempt\
     || [scan $::debugRemoteGUI {%[^:]:%d} ip port] < 2} {
        return 0
    }
    if {![catch {socket $ip $port} ::debugChannel]} {
        return 1
    }
    unset ::debugChannel
    if {$now >= $::debugNextAttempt} {
        set ::debugNextAttempt [expr {$now+1}]
    } else {
        incr ::debugNextAttempt 2
    }
    return 0
}

