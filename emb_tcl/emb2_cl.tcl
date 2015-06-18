#!/usr/bin/wish

# -----------------------------------------------------------------------------
#                                                         Configuration Section
set embeddedHostIP 127.0.0.1
set embeddedPortNr 55668

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#             USUALLY NOTHING NEEDS TO BE CHANGED BELOW THAT LINE

# -----------------------------------------------------------------------------
#                                                             Create a Tiny GUI
#
label .in\
    -relief ridge\
    -width 4\
    -font {Sans 50}\
    -textvariable adc_in
scale .out\
    -length 200\
    -orient horizontal\
    -from -99 -to 99\
    -variable dac_out\
    -command send_new_value
pack .out -side bottom -fill x
pack .in -side top -fill both -expand 1

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
    fileevent $sockfd readable [list receive_new_state]
}

# -----------------------------------------------------------------------------
#                                                   Get Changes from the Server
#
proc receive_new_state {} {
    if {[gets $::emb_socket io_value] < 0} {
        exit
    }
    if {![regexp {^([io])=(-?\d+)$} $io_value dummy io value]} {
	puts stderr "received invalid value update \"$io_value\""
        return
    }
    switch -exact $io {
        i { set ::adc_in $value }
        o { set ::dac_out $value }
    }
}

# -----------------------------------------------------------------------------
#                                                   Inform Server about Changes
#
proc send_new_value {args} {
    if {[catch {puts $::emb_socket $::dac_out; flush $::emb_socket}]} {
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
