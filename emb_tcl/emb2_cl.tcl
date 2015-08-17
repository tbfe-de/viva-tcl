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
    -from 0 -to 9999\
    -variable dac_out\
    -command send_new_value
button .quit\
     -text QUIT\
     -command exit
pack .quit -side bottom -fill x
pack .out -side bottom -fill x
pack .in -side top -fill both -expand 1

# for keyboard short-cut to quit add this:
bind . <Alt-Key-q> exit

# -----------------------------------------------------------------------------
#                                                             Connect to Server
#
proc connect_embedded {} {
    global embeddedHostIP embeddedPortNr
    if {[catch {socket $embeddedHostIP $embeddedPortNr} sockfd]} {
	puts stderr "cannot connect to $embeddedHostIP:$embeddedPortNr"
        exit
    }
    fconfigure $sockfd -blocking 0 -translation binary
    fileevent $sockfd readable [list receive_new_state]
    set ::emb_socket $sockfd
}

# -----------------------------------------------------------------------------
#                                                   Get Changes from the Server
#
proc receive_new_state {} {
    gets $::emb_socket io_value
    if {[eof $::emb_socket]} {
        exit
    }
    if {[fblocked $::emb_socket]} {
        return
    }
    if {![regexp {^([io])=(\d{1,4})$} $io_value dummy io value]} {
	puts stderr "received invalid value update \"$io_value\""
        return
    }
    switch -exact $io {
        i { set ::adc_in $value }
        o { scan $value %d value ;# get rid of leading zeroes
            set ::dac_out $value }
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
