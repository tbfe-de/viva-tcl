#!/usr/bin/wish
# =============================================================================
# Remote Trace-Debugging for Tcl Examples
# =============================================================================
# This file is used for both, to include it init the application that wants to
# generate trace/debuging output and stand-alone, as a simple GUI to view the
# messages colorized.

# -----------------------------------------------------------------------------
#                                                         Configuration Section
#
set debugRemoteGUI 127.0.0.1:55669
set debugNextAttempt [clock seconds]
array set debugMessages {
	FATAL 	{1 violet/white     }
	ERROR 	{0 red/white        }
	WARNING	{0 orange/black     }
	INFO	{0 yellow/black     }
	#TRACE	{0 lightgreen/black }
}

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#             USUALLY NOTHING NEEDS TO BE CHANGED BELOW THAT LINE

# -----------------------------------------------------------------------------
#                                   Print Severity and Message (and maybe exit)
#
proc dbg {severity message} {
    if {![info exists ::debugMessages($severity)]} return
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
    if {[lindex $::debugMessages($severity) 0]} {
        exit 127
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

# -----------------------------------------------------------------------------
#                                                 Here begins the Remote Viewer
#
puts $argv0
if {[regexp {^(.*/)?rdbg-gui(\.tcl)?$} $argv0]} {

    # -----------------------------------------------------------
    #                                  Handle Connection Requests
    proc connect {fd ip port} {
        .connected configure\
            -background green\
            -text "connected $ip:$port"
        .messages configure -state normal
        .messages delete 1.0 end
        .messages configure -state disabled
        fileevent $fd readable [list receive $fd]
    }

    # -----------------------------------------------------------
    #                                    Handle Message Reception
    proc receive {fd} {
        if {[eof $fd] || [gets $fd message] < 0} {
           close $fd
           set con [.connected cget -text]
           .connected configure\
               -background red\
               -text "dis$con"
           return
        }
        set severities [join [array names ::debugMessages] |]
        if {![regexp "($severities)" $message dummy sevtag]} {
            set sevtag ""
        }
        .messages configure -state normal
        .messages insert end $message\n $sevtag
        .messages see end
        .messages configure -state disabled
    }

    # -----------------------------------------------------------
    #                                                  Create GUI
    pack [label .connected] -side bottom -fill x
    pack [scrollbar .sb] -side right -fill y
    pack [text .messages -wrap none] -fill both
    .sb configure -command [list .messages yview]
    .messages configure -yscrollcommand [list .sb set]
    foreach tag [array names ::debugMessages] {
        set colours [split [lindex $::debugMessages($tag) 1] /]
        .messages tag configure $tag\
                -background [lindex $colours 0]\
                -foreground [lindex $colours 1]
    }
    
    socket -server connect [lindex [split $::debugRemoteGUI :] 1]
}
