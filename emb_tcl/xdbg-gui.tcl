#!/usr/bin/wish
# =============================================================================
# Extended Remote Trace-Debugging for Tcl Examples
# =============================================================================
# This file is to be run stand-alone and works as a GUI to view trace/debug
# messages generate from the part to be included into the application.

# -----------------------------------------------------------------------------
#                                                 only to get the configuration
source xdbg.tcl

# -----------------------------------------------------------------------------
#                                   redefine, so that it can be used internally
#
proc dbg {severity message} {
    set w $::applications(xdbg-gui)
    if {$::hide($severity$w)} return
    set level [info level]
    if {$level == 1} {
        set caller $::argv0
    } else {
        set caller [lindex [info level [expr {$level-1}]] 0]
    }
    if {[info exists ::hide($caller$w)] && $::hide($caller$w)} return
    add_message xdbg-gui "\[$severity] $caller: $message"
}

# -----------------------------------------------------------------------------
#                                                 helper, needed at least twice
#
proc time_stamp {} {
    set now [clock seconds]
    return [clock format $now -format "%Y-%m-%d %H:%M:%S"]
}

# -----------------------------------------------------------------------------
#                                                    handle connection requests
#
proc connect {fd ip port} {
    set conn $ip:$port
    dbg INFO "connection request from $conn"
    add_message $conn "--- connected to $conn ([time_stamp]) ---"
    set ::fd($conn) $fd
    fileevent $fd readable [list receive $conn]
}

# -----------------------------------------------------------------------------
#                                                      handle message reception
#
proc receive {conn} {
    dbg TRACE "received message from $conn"
    set fd $::fd($conn)
    if {[eof $fd] || [gets $fd message] < 0} {
        close $fd
        unset ::fd($conn)
        dbg INFO "connection closed to $conn"
        add_message $conn "--- disconnected $conn ([time_stamp])---"
        set w $::applications($conn)
        $w.display.commands configure -state disabled
        return
    }
    add_message $conn $message
}

# -----------------------------------------------------------------------------
#                                                        helper, required twice
#
proc delete_messages {w range} {
    $w.display.messages configure -state normal
    foreach {s e} $range {
        $w.display.messages delete $s $e
    }
    dbg TRACE "cleared [expr {[llength $range]/2}] range(s) in tab$w"
    $w.display.messages configure -state disabled
}

# -----------------------------------------------------------------------------
#                                  helper, required only once, but for symmetry
#
proc insert_message {w message tags} {
    $w.display.messages configure -state normal
    $w.display.messages insert end $message\n $tags
    $w.display.messages see end
    $w.display.messages configure -state disabled
}

# -----------------------------------------------------------------------------
#                                             called from GUI to clear messages
#
proc clear_messages {w {name ""}} {
    $w.display.messages configure -state normal
    if {[string equal $name ""]} {
        delete_messages $w [list 1.0 end]
        dbg INFO "cleared all messages in tab$w"
    } else {
        delete_messages $w [$w.display.messages tag ranges $name]
        dbg INFO "cleared messages in tab$w: $name"
    }
}

# -----------------------------------------------------------------------------
#                                      called from GUI to show or hide messages
#
proc hide_messages {w name} {
    set elide $::hide($name$w)
    dbg INFO "[lindex {showing hiding} $elide] messages in tab$w: $name"
    $w.display.messages tag configure $name -elide $elide
}

# -----------------------------------------------------------------------------
#                 helper to show application is stopped and waiting for command
#
proc set_command_wait {conn tf} {
    set w $::applications($conn)
    set ::stopped($conn) $tf
    $w.display.commands configure -background [lindex {lightgrey white} $tf]
}

# -----------------------------------------------------------------------------
#                           called from the GUI to run a command for inspection
#
proc send_command {conn} {
    set ::send($conn) [string trim $::send($conn)]
    if {[info exists ::fd($conn)]} {
        if {$::stopped($conn)} {
            if {[catch {
                puts $::fd($conn) $::send($conn)
                flush $::fd($conn)
            }]} {
                unset ::fd($conn)
                set_command_wait $conn 0
           } elseif {[string length $::send($conn)] == 0} {
                set_command_wait $conn 0
           }
        }
    }
    set w $::applications($conn)
    $w.display.commands selection range 0 end
}

# -----------------------------------------------------------------------------
#                                         create GUI part for message selection
#
proc create_selection {w subw name {bg_fg {}}} {
    if {[info exists ::hide($name$w)]
     || ![string is alnum $name]} {
        return ;# selection already exists
    }

    # create the checkbutton to show/hide a severity or procname
    #
    checkbutton $w.control.$subw.h$name\
        -text $name -anchor w\
        -onvalue 0 -offvalue 1\
        -variable ::hide($name$w)\
        -command [list hide_messages $w $name]
    set ::hide($name$w) 0
    if {[dict exists $::debugMessages $name hide]} {
        set ::hide($name$w) [dict get $::debugMessages $name hide]
    }
    $w.display.messages tag configure $name -elide $::hide($name$w)

    # create the button to clear a severity or procname
    #
    button $w.control.$subw.c$name\
        -text × -padx 0 -pady 0\
        -command [list clear_messages $w $name]
    if {[llength $bg_fg] > 0} {
        $w.control.$subw.c$name configure\
            -background [lindex $bg_fg 0]\
            -foreground [lindex $bg_fg 1]
    }

    # place the components into their part of the GUI
    #
    grid $w.control.$subw.h$name $w.control.$subw.c$name -sticky we
}

# -----------------------------------------------------------------------------
#                                       create GUI part for a client connection
#
proc create_connection {conn} {

    # prepare the paned window with control zone (left) and the display frame
    #
    set w .[array size ::applications]
    panedwindow $w -orient horizontal
    .master add $w -text $conn ;# -sticky nsew
    panedwindow $w.control -orient vertical
    $w add $w.control
    $w add [frame $w.display]
    $w paneconfigure $w.display

    # prepare the output area with a scrollbar and the input entry line
    #
    scrollbar $w.display.sb\
        -orient vertical -command [list $w.display.messages yview]
    text $w.display.messages\
        -wrap none\
        -yscrollcommand [list $w.display.sb set]\
        -state disabled
    entry $w.display.commands\
        -background lightgrey\
        -textvariable ::send($conn)
    set ::stopped($conn) 0
    bind $w.display.commands <Key-Return> [list send_command $conn]

    # pack the components into the display pane of the tab
    #
    pack $w.display.commands -side bottom -fill x
    pack $w.display.sb -side right -fill y
    pack $w.display.messages -fill both -expand 1

    # prepare the severity and procedure areas in the control part
    #
    $w.control add [frame $w.control.sev -borderwidth 2 -relief ridge]
    grid columnconfigure $w.control.sev 0 -weight 1
    grid columnconfigure $w.control.sev 1 -weight 0
    $w.control add [frame $w.control.proc -borderwidth 2 -relief ridge]
    grid columnconfigure $w.control.proc 0 -weight 1
    grid columnconfigure $w.control.proc 1 -weight 0

    # prepare headline and delete button for the control area (upper part) ...
    #
    label $w.control.sev.h\
        -text "Show Severities" -anchor w
    button $w.control.sev.c\
        -text × -padx 0 -pady 0\
        -command [list clear_messages $w]
    grid $w.control.sev.h $w.control.sev.c -sticky we ;# ... and bring into place

    # create selections for severities (includes bringing into place)
    #
    foreach sev [dict keys $::debugMessages] {
        if {[string equal [string index $sev 0] #]} continue
        set bg_fg [split [dict get $::debugMessages $sev colors] /]
        create_selection $w sev $sev $bg_fg
        $w.display.messages tag configure $sev\
            -background [lindex $bg_fg 0]\
            -foreground [lindex $bg_fg 1]
    }

    # prepare headline control area (lower part) ...
    #
    label $w.control.proc.h -text "Show Procedures" -anchor w
    grid $w.control.proc.h -sticky we ;# ... and bring into place

    # connection ready to use now
    #
    set ::applications($conn) $w
}

# -----------------------------------------------------------------------------
#                                      helper called for interactive inspection
#
proc do_inspection {conn sevtag} {

    # for a non-empty command, now also unhide the severity ...
    #
    set w $::applications($conn)
    if {[string length $::send($conn)] > 0} {
        set_command_wait $conn 1
        if {$::hide($sevtag$w)} {
            dbg INFO "again showing '$sevtag' messages for $conn"
            set ::hide($sevtag$w) 0
            hide_messages $w $sevtag
            $w.display.messages see end
        }
        return
    }

    # ... otherwise automatically release the application from waiting
    #
    if {[info exists ::fd($conn)]} {
        set fd $::fd($conn)
        dbg TRACE "for '$sevtag' automatically release $conn from waiting"
        if {[catch {
            # send just a newline (carefully) ...
            puts $fd ""
            flush $fd
        }]} {
            # ... disconnect in case of problems
            dbg WARNING "connection to $conn found broken"
            unset -nocomplain ::fd($conn)
        }
        set_command_wait $conn 0
    }
}

# -----------------------------------------------------------------------------
#                           add message from a connection with a given severity
#
proc add_message {conn message} {

    # if necessary, create a whole new connection tab
    #
    if {![info exists ::applications($conn)]} {
        create_connection $conn
    }
    set w $::applications($conn)
    $w.display.commands configure -state normal

    # extract severity and proc name from message ...
    #
    set severities [join [dict keys $::debugMessages] |]
    regexp "\\\[($severities)]\\s*(\[^:]+):"\
             $message dummy sevtag procname

    # ... prepare tag-list and colors ...
    #
    if {[info exists sevtag]} {
        set tags [list $sevtag]
    } else {
        set sevtag ""
        set tags [list]
    }
    if {[info exists procname]} {
        create_selection $w proc $procname
        lappend tags $procname
    }

    # ... and insert in output text area
    #
    insert_message $w $message $tags

    # finally allow interactive inspection, if requested for that severity
    #
    if {[dict exists $::debugMessages $sevtag action]} {
        set action [dict get $::debugMessages $sevtag action]
        switch -exact -- $action {
            inspect {
                do_inspection $conn $sevtag
            }
        }
    }
}

# -----------------------------------------------------------------------------
#                                                       start-up GUI and socket
#
pack [ttk::notebook .master -width 800 -height 500] -fill both -expand 1
add_message xdbg-gui "--- GUI creation completed ([time_stamp]) ---"

socket -server connect [lindex [split $::debugRemoteGUI :] 1]
dbg INFO "ready to take connections"
