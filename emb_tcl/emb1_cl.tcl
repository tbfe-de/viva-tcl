#!/usr/bin/wish
# =============================================================================
# Proof of Concept: Bidirectionally Serving Embedded System Variable Value
# =============================================================================
# This is the client-side example implementation for "emb1.tcl" - see that file
# for a complete description.

# -----------------------------------------------------------------------------
#                                                         Configuration Section
set embeddedHostIP 127.0.0.1
set embeddedPortNr 55667

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#             USUALLY NOTHING NEEDS TO BE CHANGED BELOW THAT LINE

# -----------------------------------------------------------------------------
#                                                             Create a Tiny GUI
#
foreach {cb name} {
    .water   "Water Flow Valve"
    .heater  "Electric Heater"
    .lock    "Security Door Lock"
    .sirene  "Emergency Sirene"
} {
    lappend ::name_list $name
    grid [
        checkbutton .$cb -text $name\
            -variable ::state($name)\
            -command send_new_state
    ] -sticky w
}

# -----------------------------------------------------------------------------
#                                                             Connect to Server
#
proc connect_embedded {} {
    global embeddedHostIP embeddedPortNr
    if {[catch {socket $embeddedHostIP $embeddedPortNr} sockfd]} {
	puts stderr "cannot connect to $embeddedHostIP:$embeddedPortNr"
        exit
    }
    set ::emb_socket $sockfd
    fconfigure $sockfd -blocking 0 -translation binary
    fileevent $sockfd readable [list receive_new_state]
}

# -----------------------------------------------------------------------------
#                                                   Get Changes from the Server
#
proc receive_new_state {} {
    gets $::emb_socket state
    if {[eof $::emb_socket]} {
        exit
    }
    if {[fblocked $::emb_socket]} {
        return
    }
    if {[string length $state] != [llength $::name_list]} {
        return ;# protocoll error - ignore
        # exit ;# (somewhat harder alternative)
    }
    foreach n $::name_list s [split $state ""] {
        set ::state($n) $s
    }
}

# -----------------------------------------------------------------------------
#                                                   Inform Server about Changes
#
proc send_new_state {} {
    set new_state {}
    foreach index $::name_list {
        append new_state $::state($index)
    }
    if {[catch {puts $::emb_socket $new_state; flush $::emb_socket}]} {
        catch {close $::emb_socket}
	puts stderr "disconnected from $::embeddedHostIP:$::embeddedPortNr"
        exit
    }
}

# -----------------------------------------------------------------------------
#                                                           Start-up Everything
#
connect_embedded

# -----------------------------------------------------------------------------
#                                                                          DONE
