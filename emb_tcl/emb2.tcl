#!/usr/bin/tclsh
# =============================================================================
# Proof of Concept: Bidirectionally Serving Embedded System Variable Value
# =============================================================================
# A small Tcl server (no Tk) that reads and writes a values in a pipeline-like
# digits 0 or 1 (without space in between) followed by a newline. For a real
# application imagine the files were an ADC and a DAC, reflecting the values
# read from and written to it (and maybe assume the ADC follows the DAC with
# some delay, maybe from an RC-circuit).
#
# The server responds to connection requests over an IP-socket from programs
# like "emb2_client.tcl":
# - With any new value read from the ADC the clients get informed about the
#   new value, and any value set by the client will be communicated to the DAC.
# - Also there may be any number of clients which automatically see the changes
#   from other clients.
#
# Note: In this example synchroneous reads from the ADC are used, assuming an
#       appropriate driver that will block input requests until data is ready.
#       (You may want to see "emb1.tcl" (and "emb1_client.tcl") in which the
#       server side connects to the (hypothetical) hardware via polling.)

# -----------------------------------------------------------------------------
#                                                         Configuration Section
#
set serverIpPortNr 55668
set deviceFile_ADC adc_value
set deviceFile_DAC dac_value
set deviceFileFormat {-?[0-9]+}
set deviceLastValue_in 0
set deviceLastValue_out 0

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
    client_send "i=$::deviceLastValue_in" $fd
    client_send "o=$::deviceLastValue_out" $fd
    fileevent $fd readable [list client_receive $fd]
}

# -----------------------------------------------------------------------------
#                                            Receive Changes on the Client Side
#
proc client_receive {fd} {
    if {[gets $fd value] < 0} {
        close $fd
        dbg INFO "unregistering client $::clients($fd)"
        array unset ::clients($fd)
        return
    }
    if {![regexp "^$::deviceFileFormat$" $value]} {
        dbg ERROR "received invalid data from $::clients($fd): \"$value\""
        # alternative to consider: close connection at this point
        return
    }
    if {[catch {puts $::dac_fd $value; flush $::dac_fd} message]} {
        dbg ERROR "cannot write \"$value\" to $::deviceFile_DAC: $message"
        # alternative to consider: make a fatal error
        return
    }
    client_send "o=$value" [array names ::clients]
}

# -----------------------------------------------------------------------------
#                       Attach to the DAC (like on the write-end of a pipeline)
#
proc dac_attach {} {
    unset -nocomplain ::dac_fd
    dbg INFO "attaching to DAC $::deviceFile_DAC"
    if {[catch {open $::deviceFile_DAC {WRONLY}} devfd]} {
        dbg FATAL "cannot open device-file for writing: $devfd"
        error $devfd
    }
    set ::dac_fd $devfd;
}

# -----------------------------------------------------------------------------
#                        Attach to the ADC (like on the read-end of a pipeline)
#
proc adc_attach {} {
    unset -nocomplain ::adc_fd
    dbg INFO "attaching to ADC $::deviceFile_ADC"
    if {[catch {open $::deviceFile_ADC {RDONLY NONBLOCK}} devfd]} {
        dbg FATAL "cannot open device-file for reading: $devfd"
        error $devfd
    }
    fconfigure $devfd -blocking 1
    set ::adc_fd $devfd
    fileevent $devfd readable adc_read
}

# -----------------------------------------------------------------------------
#                                                      Read Values from the ADC
#
proc adc_read {} {
    if {[eof $::adc_fd]} {
        catch {close $::adc_fd}
        unset ::adc_fd
        dbg ERROR "eof on adc device -- re-open after grace period"
        after 5000 adc_attach
        return 
    }
    if {[catch {gets $::adc_fd} value]} {
        dbg FATAL "error on adc device $::deviceFile_ADC: $value"
        error $value
    }
    if {![regexp "^$::deviceFileFormat$" $value]} {
        dbg WARN "ignored invalid adc-data from $::deviceFile_ADC: \"$value\""
        return 0
    }
    set ::deviceLastValue_in $value
    client_send "i=$value" [array names ::clients]
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
        dbg INFO "updated $cnt clients with new value \"$what\""
    }
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

dbg INFO "attach ADC at $deviceFile_ADC"
adc_attach

dbg INFO "attach DAC at $deviceFile_DAC"
dac_attach

dbg INFO "starting event loop now ..."
vwait forever

# -----------------------------------------------------------------------------
#                                                                          DONE
