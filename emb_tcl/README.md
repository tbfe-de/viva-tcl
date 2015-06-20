## Code-Walk

This directory contains seven examples total, which are introduced in the presentation and explained in more detail
now.

### Overview

Four of the examplkes are actually pairs of a "server" and a matching "client", all fully written in Tcl. They
demonstrate how an Embedded Board (presumable running under Linux) might communicate an be controlde with respect
to its state by a remote application, based on a TK-GUI.

See later sections "Binary State – Polled" and "ADC / DAC – Streamed" fpr details.

The other three examples deal with debug tracing in various comfortable way. Note that these are NOT meant to compete
with (semi-) professional Tcl-IDEs and -debuggers, they just shall demonstrate how MUCH you can do with only a LITTLE
bit of Tcl/Tk-Code.

### Binary State – Polled

Under Linux (though with its origin in "Plan 9", the Unix follow-up created in the early 90's at AT&T) it is state of
the art to represent I/O-pins via a device driver as (pseudo-) file, which then can be read or written by any
application that is able to operate on (text-) files.

Beyond that little assumptions can be made, e.g. with respect to the data in the pseudo-file, it might be text or
binary. Here it is assumed that the device driver is our friend, reflecting the current and receiveing a modified
pin state as usual characters '0' and '1', i.e. ASCII 0x110000 and 0x110001. Thuis makes it content easier in most
scripting languages, including Tcl, but only marginally: few lines would have to be added if the state were
represented in separate bits of a word (8, 16, 32 bit, ...) or a sequence thereof.

To try the examples without any device driver presenting real I/O-pins as pseudo-file, just create an ordinary text
file:

```
echo 0000 >port_pins
```

in the directory which is the current directory when you run `emb1.tcl` (the "server") and `emb1_cl.tcl` (the client).

Start the former first in the background
```
./emb1.tcl &
```

then the latter:

```
./emb1_cl.tcl
```

**Note:**

To keep things easy some assumptions are hard-wired in the Tcl code, especially the path name to the interpreters
(`tclsh` and `wish`), if such are different on your system, simply change the files accordingly or name the
interpreter explicitly:
```
tclsh emb1.tcl & wish tcl1_cl.sh
```

If you want to go beyond a simple demo on a single PC, you will also need to adapt the IP addresses and maybe the port
numbers used for the TCP/IP socket, but this should be obvious from a cursory look at the code, you need not be a
Tcl expert to do this.

#### `emb1.tcl`

Despite it is a really brief Tcl program, this "server" is able to **connect to any number of `emb1_cl.tcl` clients**
and will care for

* reflecting state changes in the file `port_pins` from the file to each client,
* from any client to the file `port_pins`, and (of course)
* between the clients.

So, what you may want to try now is change the file `port_pins` by

```
echo 0101 >port_pins
echo 1111 >port_pins
```

and watch how the client(s) update.

[Try this with a full-blown or just a mininal HTTP server on the embedded board, maybe JavaScript on the client, well
and then throw in some PHP ... I'm (not really) curious how many lines of code you will need. Anyway you will need to
acquire competence in a number different areas. Now compare this to the Tcl approach: you need to gather competence
too, but only in Tcl, and you can profit from it as Vivado user! IMHO the second best approach (or best approach for
"Non-Tclers") were to acquire competence with JavaScript and use node.js on the embedded side, but that's just my
2 cent ...]

#### `emb1_cl.tcl`

This implements the client with a GUI but has even less lines of code as the server! If you are fluent in C++ and Qt
you may be able to beat it, but again, if you need to learn Qt only to do THIS, better stick with Tk, it is extremely
portable too, though – admitetdly – misses some of the nifty "modern" control elements and hence may appear
old-fashioned ... at least in comparison it to the latest super-duper smart phone, advertised from the big sellers
who want to draw the money from your pockets in intervals of 18 months ...)

So, what you may want to try now is to click the check-boxes and watch how the file changes by doing a
```
cat port_pins
```

and if this gets boring, start some more `emb1_cl.tcl` clients and watch how changing the check-boxes in any of it
will immediately display the state of the others.


