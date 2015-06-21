#!/usr/bin/tclsh
# =============================================================================
# Proof of Concept: Bidirectionally Serving Embedded System State (= 4 flags)
# =============================================================================
# A small Tcl server (no Tk) that reads and writes a file containing four
# digits 0 or 1 (without space in between) followed by a newline. For a real
# application imagine # the file actually were a device, reflecting the state
# of some I/O pins, with the inputs and outputs connected, so that the 0/1
# values which are set can be read back (and the outputs may be overdriven by
# stronger input).
#
# The server responds to connection requests over an IP-socket from programs
# like "emb1_client.tcl":
# - Any change of any of the four state flags will be communicated between
#   server and client, so that changes on each side becomes visible on the
#   other side.
# - Also there may be any number of clients which automatically see the
#   changes from other clients.
#
# Note: In this example the device state is polled in regular intervals.
#       (You may want to see "emb2.tcl" (and "emb2_client.tcl") in which the
#       server side connects to the (hypothetical) hardware in a pipeline-like
#       fashion.)

# -----------------------------------------------------------------------------
#                                                         Configuration Section
#
set serverIpPortNr 55667
set deviceFileName port_pins
set deviceFileFormat {[01]{4}}
set deviceFilePoll 100 ;# msec
set deviceLastState ""

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#             USUALLY NOTHING NEEDS TO BE CHANGED BELOW THAT LINE

# -----------------------------------------------------------------------------
#                                                      Store Remote Connections
#
array set clients {}

# -----------------------------------------------------------------------------
#                                   Respond to Connection Requests from Clients
#
proc client_connect {fd ip port} {
    dbg INFO "connection request from $ip:$port"
    set ::clients($fd) $ip:$port
    if {[device_read currentstate]} {
        client_send $currentstate $fd
    }
    fileevent $fd readable [list client_receive $fd]
}

# -----------------------------------------------------------------------------
#                                            Receive Changes on the Client Side
#
proc client_receive {fd} {
    if {[gets $fd state] < 0} {
        close $fd
        dbg INFO "unregistering client $::clients($fd)"
        array unset ::clients($fd)
        return
    }
    if {![regexp "^$::deviceFileFormat$" $state]} {
        dbg ERROR "received invalid data from $::clients($fd) - $state"
        # alternative to consider: close connection at this point
        return
    }
    if {[catch {open $::deviceFileName w} devfd]} {
        dbg FATAL "cannot open device-file for writing: $devfd"
        error $devfd
    }
    dbg TRACE "opened $::deviceFileName for writing"
    if {[catch {puts $devfd $state; close $devfd} message]} {
        dbg ERROR "cannot write \"$state\" to $::deviceFileName: $message"
        return
    }
    dbg INFO "written \"$state\" to $::deviceFileName"
}

# -----------------------------------------------------------------------------
#                                                         Read the Device State
#
proc device_read {_state} {
    upvar $_state state
    if {[catch {open $::deviceFileName r} devfd]} {
        dbg FATAL "cannot open device-file for reading: $devfd"
        error $devfd
    }
    if {[gets $devfd state] < 0} {
        dbg ERROR "cannot read device state from $::deviceFileName: $devfd"
        close $devfd
        return 0
    }
    if {![regexp "^$::deviceFileFormat$" $state]} {
        dbg ERROR "read invalid device-data from $::deviceFileName - $state"
        close $devfd
        return 0
    }
    close $devfd
    return 1
}

# -----------------------------------------------------------------------------
#                                                   Send Changes to the Clients
#
proc client_send {what whom} {
    set cnt 0
    foreach clientfd $whom {
        if {[catch {puts $clientfd $what; flush $clientfd} message]} {
            dbg ERROR "cannot write socket to $::clients($clientfd): $message"
            dbg WARN "closing socket to $::clients($clientfd)"
            close $clientfd
            dbg INFO "unregistering client $::clients($clientfd)"
            unset ::clients($clientfd)
            continue
        }
        incr cnt
    }
    if {$cnt > 0} {
        dbg INFO "updated $cnt clients with new device state \"$what\""
    }
}

# -----------------------------------------------------------------------------
#                                                   Poll the Device for Changes
#
proc device_poll {} {
    dbg STOP "polling device state"
    if {[device_read newstate]\
     && ![string equal $newstate $::deviceLastState]} {
        client_send $newstate [array names ::clients]
        set ::deviceLastState $newstate
    }
    after $::deviceFilePoll device_poll
}

# -----------------------------------------------------------------------------
#                                                      Load Debug Output Helper
#
if {[catch {source dbg.tcl}]} {proc dbg args {}}

# -----------------------------------------------------------------------------
#                                                           Start-up Everything
#
dbg INFO "set-up to listen for connection requests at port $serverIpPortNr"
socket -server client_connect $serverIpPortNr

dbg INFO "set-up to poll port-pins $deviceFileName every $deviceFilePoll msec"
after 0 device_poll

dbg INFO "starting event loop now ..."
vwait forever

# -----------------------------------------------------------------------------
#                                                                          DONE
