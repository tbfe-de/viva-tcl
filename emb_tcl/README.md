## Code-Walk

This directory contains seven examples total, which are introduced in the presentation and explained in more detail
now.

### Overview

Four of the examplkes are actually pairs of a "server" and a matching "client", all fully written in Tcl. They
demonstrate how an Embedded Board (presumable running under Linux) might communicate an be controlde with respect
to its state by a remote application, based on a TK-GUI.

See later sections "Binary State – Polled" and "ADC / DAC – Streamed" for details.

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

### ADC / DAC – Streamed

These example demonstrates a slightly different approach ot communicate with the state of the embedded device based
on pseudo files:

* There is one file that "produces" values at random times – i.e. a data source, and
* another file that "swallows" any values written to it – i.e. a data sink.

Again, to keep things simple, the names of these files are hardwired to `dac_value` and `adc_value` but simple to
change. (Last not least, the examples are rather meant as "proof of concept", but written clean enough to base a
product solution on them, besides just drawing on the idea.)

To try the demons without a real deivce driver representing a ADC or DAC via such pseudo-files, just create two
named pipes:
```
mkfifo dac_value
mkfifo adc_value
```

Then connect the first on with a `cat`-command that shows any value written to it and prepare to supply values for
the second one via the keyboard:
```
cat -u dac_value &  # <--- note the & for background execution!
cat -u adc_value    # <--- NO & as you want to supply values!
```

**Hint:**

You may also do the above from different terminals (consoles). This would help to avoid to confuse what is input and
what is output. But you are well able to do everything from a single terminal, though in this case it will probably
pay to first get comfortable with  the job control features of your shell (i.e. `CTRL-Z`, `fg` and `bg` commands,
and eventually `jobs` and `kill %n` too).

#### `emb2.tcl`

Again a really compact server, able to serve as many `emb2_cl.tcl` clients as are started. Other than in `emb1.tcl`
which usespolling to notice changes on `port_pins` and send updates to the client(s), `emb2.tcl` it is completly
event-driven:

* Besides the callback registered  via the `socket` command for incomming connection requests, and
* the callback registered with `fileevent` to be notified when data is received over the socket, also
* **any new values comming in through `adc_value` are received via a callback registered with `fileevent`**.

Therefore there is no necessity for a compromise between CPU load (generated by busy waiting) and sub-optimal latency.

*Bbut nevertheless be aware:**

In case data is not read as fast from `dac_value` as is written by `emb2.tcl`, the server might be stopped hanging in
a wait for buffer space in socket output to become available.

In practice however, this will hardly ever happen if the scenario is that `adc_value` and `dac_value` are actually
pipelines to and from buffers in an FPGA design (remember: this all has been created for a talk to developers
intending to use Tcl with Vivado), this will proabably never happen. Instead, a more serious issue were slow reads
from `adc_value`, which on the FPGA side must be taken care of, e.g. by purging a number of old values when the
consumer (at the read-end on the pseudo device in Linux) is not able to keep pace.

#### emb2_cl.tcl

As the input and output (`dac_value` and `dac_value`) are a distinct source and sink, this client too handles
incoming and outgoing values differently:

* The first are displayed in a `label` (in Tk terminology), while
* the second can be set via a slide control (aka. `scale` in Tk terminology).

But as before you may start any number of clients you like, and all will display the same value – the last one fed
into the `adc_value` pipe – and all will synchronice their slider if it is movre in anyone, and of course each new
will arrive in `dac_value`, no matter which client set it.

Just give it a try!

### A Note on Robustness

As has been shown, with regard to the input side registering callbacks with `fileevent` provides a nice solution to
avoid arbitrary blocking, which would kill the idea of a event-driven design.

**But it should be understood that blocking may not only happen on input but on output too** (as shortly mentioned
with respect to the `dac_value` pipeline or pseudo-file). Therefore it may be considered to use `fileevent` for
output. In principle this is not a difficult modification, but it needs some logic to decide what happens with data
generated internally too fast to be sent.

Last and finally a robust design must also consider how far each of both sides – server and client – trusts the
correct implementation of the other. If there is the necessary amount of mutual trust (for a correct implementation
and as long as unreliable or deliberately cheating communication partners can be averted in the first place, to avoid
waiting on output a protocol may be uses n which the producer of some data discards everything until the consumer
has indicated its readiness to receive another chunk of data.

### Debug-Tracing

TBD

#### The Basics: `dbg.tcl`

TBD

#### Viewing Debug-Traces Remotely: `rdbg.tcl` and `rdbg-gui.tcl`

TBD

#### An Advanced Debug-Trace Viewer: `xdbg.tcl` and `xdbg-gui.tcl`

TBD

## Conclusion

TBD
