#!/bin/echo "to be read with 'source' -- not for stand-alone use"
# =============================================================================
# Trace-Debugging for Tcl Examples
# =============================================================================
#

# -----------------------------------------------------------------------------
#                                                         Configuration Section
#
set debugChannel stderr
array set debugMessages {
	FATAL 	1
	ERROR 	0
	WARNING	0
	INFO	0
	#TRACE	0
}

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#             USUALLY NOTHING NEEDS TO BE CHANGED BELOW THAT LINE

# -----------------------------------------------------------------------------
#                                   Print Severity and Message (and maybe exit)
#
proc dbg {severity message} {
    if {![info exists ::debugMessages($severity)]} {
	return
    }
    set level [info level]
    if {$level == 1} {
        set caller $::argv0
    } else {
        set caller [lindex [info level [expr {$level-1}]] 0]
    }
    puts $::debugChannel "\[$severity] $caller: $message"
    flush $::debugChannel
    if {$::debugMessages($severity)} {
        exit 127
    }
}
