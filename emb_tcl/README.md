## Code-Walk

This directory contains seven examples total, which are introduced in the presentation and explained in more detail
here.

### Overview

Four of the examples are actually pairs of a *Server* and a matching *Client*, all fully written in Tcl. They
demonstrate how an Embedded Board (presumable running under Linux) is enabled to communicate over an TCP/IP stream
socket an is controlled with respect to its state by a remote application with a Tk-based GUI.

See later sections [Binary State – Polled](#binary-state--polled) and
[ADC / DAC – Streamed](#adc--dac--streamed) for details.

The other three examples deal with [Debug-Tracing](#debug-tracing) in various ways. Note that these are NOT meant
to compete with (semi-) professional Tcl-IDEs and -debuggers, they just shall demonstrate how *MUCH* you can do with
only a *LITTLE* bit of Tcl/Tk-Code.

[`emb1.tcl`]:     emb1.tcl
[`emb1_cl.tcl`]:  emb1_cl.tcl
[`emb2.tcl`]:     emb2.tcl
[`emb2_cl.tcl`]:  emb2_cl.tcl
[`dbg.tcl`]:      dbg.tcl
[`rdbg.tcl`]:     rdbg.tcl
[`xdbg.tcl`]:     xdbg.tcl
[`xdbg-gui.tcl`]: xdbg-gui.tcl

### Binary State – Polled

Under Linux it is state of the art to represent I/O-pins via a device driver as (pseudo-) file, which then can be
read or written by any application that is able to operate on (text-) files.

Beyond that little assumptions can be made, e.g. with respect to the data in the pseudo-file, it might be text or
binary. Here it is assumed that the device driver is our friend, reflecting the current and receiving a modified
pin state as usual characters '0' and '1', i.e. ASCII 0x110000 and 0x110001. This makes it content easier in most
scripting languages, including Tcl, but only marginally: few lines would have to be added if the state were
represented in separate bits of a word (8, 16, 32 bit, ...) or a sequence thereof.

To try the examples without any device driver presenting real I/O-pins as pseudo-file, just create an ordinary text
file:

```
echo 0000 >port_pins
```

in the directory which is the current directory when you run `emb1.tcl` (the server) and `emb1_cl.tcl` (the client).

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
tclsh emb1.tcl & wish emb1_cl.sh
```

If you want to go beyond a simple demo on a single PC, you will also need to adapt the IP addresses and maybe the port
numbers used for the TCP/IP socket, but this should be obvious from a cursory look at the code, you need not be a
Tcl expert to do this.

#### [`emb1.tcl`]

Despite it is a really brief Tcl program, the server is able to **connect to any number of `emb1_cl.tcl` clients**
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

[Try this with a full-blown or just a minimal HTTP server on the embedded board, maybe JavaScript on the client, well
and then throw in some PHP ... I'm (not really) curious how many lines of code you will need. Anyway you will need to
acquire competence in a number different areas. Now compare this to the Tcl approach: you need to gather competence
too, but only in Tcl, and you can profit from it as Vivado user! IMHO the second best approach (or best approach for
"Non-Tclers") were to acquire competence with JavaScript and use node.js on the embedded side, but that's just my
2 cent ...]

#### [`emb1_cl.tcl`]

This implements the client with a GUI but has even less lines of code as the server! If you are fluent in C++ and Qt
you may be able to beat it, but again, if you need to learn Qt only to do THIS, better stick with Tk, it is extremely
portable too, though – admittedly – misses some of the nifty "modern" control elements and hence may appear
old-fashioned ... at least in comparison it to the latest super-duper smart phone, advertised from the big sellers
who want to draw the money from your pockets in intervals of 18 months ...)

So, what you may want to try now is to click the check-boxes and watch how the file changes by doing a
```
cat port_pins
```

and if this gets boring, start some more `emb1_cl.tcl` clients and watch how changing the check-boxes in any of it
will immediately display the state of the others.

### ADC / DAC – Streamed

These example demonstrates a slightly different approach to communicate with the state of the embedded device based
on pseudo files:

* There is one file that "produces" values at random times – i.e. a data source, and
* another file that "swallows" any values written to it – i.e. a data sink.

Again, to keep things simple, the names of these files are hardwired to `dac_value` and `adc_value` but simple to
change. (Last not least, the examples are rather meant as "proof of concept", but written clean enough to base a
product solution on them, besides just drawing on the idea.)

To try the demons without a real device driver representing a ADC or DAC via such pseudo-files, just create two
named pipes:
```
mkfifo dac_value
mkfifo adc_value
```

Then connect the first on with a `cat`-command that shows any value written to it and prepare to supply values for
the second one via the keyboard:
```
cat -u <dac_value &  # <--- note the '&' for background execution!
cat -u >adc_value    # <--- NO '&' as you want to supply values!
```

**Hint:**

You may also do the above from different terminals (consoles). This would help to avoid confusing what is input and
what is output. But you are well able to do everything from a single terminal, though in this case it will probably
pay to first get comfortable with the job control features of your shell (i.e. `CTRL-Z`, `fg` and `bg` commands,
and eventually `jobs` and `kill %n` too).

#### `emb2.tcl`

Again a really compact server, able to serve as many `emb2_cl.tcl` clients as are started. Other than in `emb1.tcl`
which uses polling to notice changes on `port_pins` and send updates to the client(s), `emb2.tcl` it is completely
event-driven:

* Besides the callback registered  via the `socket` command for incoming connection requests, and
* the callback registered with `fileevent` to be notified when data is received over the socket, also
* **any new values coming in through `adc_value` are received via a callback registered with `fileevent`**.

Therefore there is no necessity for a compromise between CPU load (generated by busy waiting) and sub-optimal latency.

**But nevertheless be aware:**

In case data is not read as fast from `dac_value` as is written by `emb2.tcl`, the server might stop hanging in
a wait for buffer space in socket output to become available.

In practice however, this will hardly ever happen if the scenario is that `adc_value` and `dac_value` are actually
pipelines to and from buffers in an FPGA design (remember: this all has been created for a talk to developers
intending to use Tcl with Vivado). Instead, a more serious practical issue were slow reads from `adc_value`, which
on the FPGA side must be taken care of, e.g. by purging a number of old values when the consumer (at the read-end
of the pseudo device in Linux) is not able to keep pace.

#### `emb2_cl.tcl`

As the input and output (`dac_value` and `dac_value`) are a distinct source and sink, this client too handles
incoming and outgoing values differently:

* The first are displayed in a `label` (in Tk terminology), while
* the second can be set via a slide control (aka. `scale` in Tk terminology).

But as before you may start any number of clients you like, and all will display the same value – the last one fed
into the `adc_value` pipe – and all will synchronise their sliders if it is moved in any of them, and of course
each new will arrive in `dac_value`, no matter which client set it.

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
waiting on output a protocol may be uses in which the producer of some data discards everything until the consumer
has indicated its readiness to receive another chunk of data.

### Debug-Tracing

While for large projects using one of the commercial or free IDEs for Tcl may make sense, small programs like the ones
shown here can also be easily written in a text editor (the well-known ones often have syntax highlighting for many
programming languages, including a Tcl-mode).

To understand the reason for a misbehaving program, then during development output statements are inserted at the
points of interest. (This is why this technique is often called`printf`-debugging in C, and hence might be called
`puts` debugging in Tcl.)

A slightly more systematic approach is to sprinkle a program with trace output at all its strategic points, like
entry to and exit from function, important conditions not met (leading to an unusual path been taken) and more. Then
the art is to decide which points are worth to generate a trace message, so that only a moderate amount of output
is created ordinarily but always enough to analyse misbehaviour and find where to fixed it.

As trade-off between too little and too much trace output is usually hard to make, and often there is no real
compromise that fulfils the needs of both, that of the developers during testing and debugging and that productive
use with a decent amount of logging, trace messages can often be switched on and of dynamically or at  program
start-up, often by their category (from rare errors and warning to rather chatty traces), or also by other criteria
like the module or function which they originate from.

The more sophisticated ideas like the one set forth in the last paragraph may also appear more difficult to realise,
but actually isn't in Tcl, due to its introspection features. The following elaborates three approaches, from very
basic to slightly advanced.

**All three are designed with the same interface to the application, so the decision which one to use may be made
(and changed) at any time, just by changing one line of code (or alternatively by renaming a file).

#### The Basics: `dbg.tcl`

Trace messages have already become evident from watching the output to the terminal (console) when one of the
server applications (`emb1.tcl` and `emb2.tcl`) runs. Here is some output captured after start-up of `emb1.tcl`
up to the point where the first client `emb1_cl.tcl` has connected and changed a pin value:

```
[INFO] ./emb1.tcl: set-up to listen for connection requests at port 55667
[INFO] ./emb1.tcl: set-up to poll port-pins port_pins every 100 msec
[INFO] ./emb1.tcl: starting event loop now ...
[INFO] client_connect: connection request from 127.0.0.1:60118
[INFO] client_send: updated 1 clients with new device state "0010"
[INFO] client_receive: written "1010" to port_pins
[INFO] client_send: updated 1 clients with new device state "1010"
```

Obviously there is a categorisation included (in square brackets) followed by either the name of the application
itself or one of its functions, from which the message originates, up to a colon.

Looking for the points where such messages are sent reveals the unique use of a function `dbg` to generate such
messages.

This is a fragment from the end of `emb1.tcl` (outside any function):
```
dbg INFO "set-up to listen for connection requests at port $serverIpPortNr"
socket -server client_connect $serverIpPortNr

dbg INFO "set-up to poll port-pins $deviceFileName every $deviceFilePoll msec"
after 0 device_poll

dbg INFO "starting event loop now ..."
vwait forever
```

And here are some lines from `client_receive` (the dots … indicated where more lines from this function have
been elided):
```
proc client_receive {fd} {
    if {[gets $fd state] < 0} {
        close $fd
        dbg INFO "unregistering client $::clients($fd)"
        …
    }
    …
    dbg TRACE "opened $::deviceFileName for writing"
    …
    dbg INFO "written \"$state\" to $::deviceFileName"
}
```

Obvioulsy the category is the first argument to `dbg` and the message itself the second argument, **though without
the application or function name!**

How can that work?

As the function `dbg` is not defined by the application itself but in the file `dbg.tcl`, the solution can be seen
here (again only showing the relevant fragment):
```
proc dbg {severity message} {
    …
    set level [info level]
    if {$level == 1} {
        set caller $::argv0
    } else {
        set caller [lindex [info level [expr {$level-1}]] 0]
    }
    puts $::debugChannel "\[$severity] $caller: $message"
    …
}
```

The solution to the puzzle is the use `info level`, one of Tcl's powerful introspection features, that allows any
function not only to find out its own name but also the name of its caller.

(Reviewing the `dbg` function further and finding out how it can be configured with respect to the messages shown
and which messages will actually terminate the program is not that hard and left as an exercise to the reader.)

A final little gem to show before advancing to a slightly more elaborate way of viewing trace and debug output can
be find where the file `dbg.tcl` is included into the server application (close to its end):
```
if {[catch {source dbg.tcl}]} {proc dbg args {}}
```

What is this?

It is a nifty way to either include the content of the file `dbg.tcl` but if that fails it nevertheless defines the
subroutine `dbg`, to accept any number of arguments, but doing nothing in its body.

So, if `dbg.tcl` isn't present, no debug output at all will be generated (only program execution is slowed down by
a tiny amount of time wherever the now "useless" subroutine `dbg` is called.

Try it now – maybe rename `dbg.tcl` to `bdbg.tcl` … (with the `b` standing for **b**asic debugging support, as now
is the time to turn to a more elaborate way of viewing the trace output).

#### Viewing Debug-Traces Remotely: `rdbg.tcl` and `rdbg-gui.tcl`

First of all: `rdbg.tcl` and `rdbg-gui.tcl` are actually the identical, i.e. the first is the file and the second
just a symbolic link (alias name). Keep it in mind, though this will get important a little later.

The main thing changed here from the perspective of the application making trace output available to interested
parties is …

* … **nothing** if it comes to calling the subroutine `dbg` (i.e. "no change in the API"),
* but nevertheless substantial when it comes to viewing messages, which is now possible anywhere in the network.
 
**Remember:**

This series started out motivated as an example where the "servers" run on an embedded board and though you might
have some way to watch its console output, e.g. over an `ssh` connection or serial line, wouldn't it be nice to
avoid cluttering these connections with trace messages and have them freely available for other purposes? (Or, if
you go over USB from RS232, to avoid having to use these sometimes cumbersome and whimsical port converters?)

The other good news is this: all you need to change in your application is that one line
```
if {[catch {source rdbg.tcl}]} {proc dbg args {}}
```
so that now `rdbg.tcl` is included. This actually changes the implementation of `dbg` to use a socket connection,
**if some viewer is present at the configured port**.

Again, please note that these demo applications are meant for setting forth the idea, and a production solution
might need some polishing, like configurable ip numbers and ports, which are hardwired here in the configuration
section:
```
set debugRemoteGUI 127.0.0.1:55669
```

So, what happens now if `emb1.tcl` or `emb2.tcl` is started?

* As soon as it wants to send out its first trace message it will try to contact the viewer application on the same
  host (`127.0.0.1` is just another way to say `localhost`) at port `55669` …
* … and if there is no one listening at that port, nothing at all happens.

So, effectively it depends on whether the viewer runs or not, to get or discard any trace output.

**A note to those who worry about efficiency:**

Obviously it creates runtime (and maybe network) overhead to try to connect to non-existing IP ports. Therefore you
would probably consider to rename `rdbg.tcl` to something different (or remove the file completely) as long as you
definitely need no trace output, as calling a subroutine with an empty body (as explained at the end of the last
section).

But in case there is "usually" a viewer running but only sometimes "down" (for any reason), its unavailability is not
considered as "hard" error and there is even some logic to reduce the number of connection requests if they fail
frequently in a row.

And now for the next question: Where do you find the ominous viewer app?

You have it right there in front of your eyes – it is part of `rdbg.tcl` but will only start running if you call that
with a name that ends in `-gui.tcl`, i.e. the alias name already existing as symbolic link!

So start it now:
```
./rdbg-gui.tcl
```

(The configuration section has also been a little extended over `dbg.tcl`, especially you might configure foreground
and background colours to your taste, but again finding out such details ias left as an exercise to the reader.)

The viewer itself is deliberately kept small and simple, it should only introduce to some more Tk features for GUI
programming and wet your appetite for more,

… which follows now …

… and this time it will be not just some baby-steps, let us take a really big leap (at least when measured in LOC).

#### An Advanced Debug-Trace Viewer: `xdbg.tcl` and `xdbg-gui.tcl`

Just to give you an idea first: what follows here has been written from scratch in about one working day by a
*"moderately experienced Tcl/Tk developer"* who knows Tcl/Tk for a bit more than 15 years, but has his most
current and main experience in the area of C/C++ (=me :-)) Especially I have written NO non-trivial Tcl application
with a size and complexity comparable to `xdbg-gui.tcl` in the last five years before (though I taught a number of
Tcl courses during that time).

Contrary to the remote trace viewer introduced in the last section, `xdbg.tcl` and `xdbg-gui,tcl` are different
files, with the former to be included in the application calling the `dbg` subroutine and the latter implementing
the viewer with the Tk GUI.

For the latter, writing a small manual may be appropriate, but this will easily take more time as writing the
program itself and so I defer it for now. Instead I will only give a sketchy description of its behaviour that
also points out some of its highlights:

* On start-up `xdbg-gui.tcl` shows a single tab which is meant to show "trace output" of itself.
* When another program is running that has included `xdbg.tcl` generates trace output with calls to `dbg` …
* … a new tab will be opened by `xdbg-gui.tcl` to view the messages.
* All available message categories are listed on the upper part of the left pane, and …
* … all current messages can be hidden or made visible again by clicking the according check-boxes, or …
* … permanently removed by clicking on the `×`-buttons.
* Moreover, as soon as messages come in from specific subroutines …
* … their names collect in the lower part of the left pane …
* … and can be shown/hidden or permanently removed in the same way.

Also the configuration in `xdbg.tcl` has been more elaborated and now uses a Tcl `dict`. This allows to use a
hierarchical style (actually somewhat similar to JSON syntax, but without a colon after the key).

This shows a representative fragment:
```
set debugMessages {
    FATAL {                         
        action die
        colors violet/white 
    }
    ERROR {
        action show 
        colors red/white
    }
    …
    STOP {
        action inspect
        hide true
        colors black/white
    }
}
```

(To view it fully see the source file – it also has rudimentary documentation on this in the comments above.)

Besides message colouring also the behavior can be specified via `action` in more detail on a per category base.

Of special interest may be the `action inspect` here, which crosses the border from a pure viewer to an interactive
inspection tool. Assigning a messages category the `action inspect` will have the following effect:

* Issuing a message from that category cause the application to halt and wait for *inspection commands*.
* Such are issued from the text entry field at the bottom of the tabs.
* Any valid Tcl command can be used as *inspection command*, and …
* … **such commands and are executed in the traced application at the stack level of the issuer** …
* … and their output is displayed in the text area above …
* … until an empty line is entered.

Though compared to an advanced debugger allowing to set arbitrary breakpoints at source file level this is still a
rather primitive debugging. Nevertheless the generic style of interaction via Tcl commands is extremely powerful.

Assuming the message that has caused the application to (temporarily) stop comes from subroutine `foo`, it is now
easy to

* list the source code of that function (with `info body foo`),
* find out which are its argument names (with `info body args`), or
* *inspect* or even *change(!)* any argument, local or global variable.

(In fact, while arguments, local, and global variables are typically the ones of interest, Tcl's `uplevel` command
allows inspection and modification of variables at each stack level.)

## Conclusion

Tcl is a very powerful scripting language.

It might not be considered as "modern language" (depending on the criteria you choose to apply that label), but
it is **very robust**, **very portable**, and far from being dead or ready to be trashed.

Also its "shell-style" approach (with minimal syntax and nearly everything implemented via its "library") may not
match everybody's taste, but those who get around this will usually appreciate the flat learning curve with a very
low initial step.

Tcl's readiness for productive use has often been demonstrated, once more here, with the examples shown mainly aiming
to demonstrate a decent number of Tcl features in the server, and of Tk in the clients and in the debug viewers.

If you are programming an embedded device, especially one based on Linux, and you want to give it a remote control 
application with a GUI, you need not acquire any expertise in the area of HTTP servers or programming languages
"typically" used on the server side (PHP) or the client side (JavaScript).

If you think it is a downside that you "need some software besides a browser" on the remote side (controlling the
embedded device), i.e. `wish` (`tclsh` bundled with Tk) **plus** a Tcvl/Tk application (similar to the `*_cl.tcl`
clients shown here), it may be of interest to learn that both can be bundled into a single executable file that may
even be carried around on a memory stick. 

**Hence, purging the necessity of an HTTP server on the embedded device and a browser on the remote side, with all
the intricacies following from it, like potential security wholes – typically in widely distributed software you
depend on and requiring an urgent fix once it is publicly known – a remote control application in form of
specialised software may even be considered a boon, but a burden (and anyway a very minimal one).

Tcl on the embedded device combined with and Tk for the GUI is fully sufficient, and especially if you are an FPGA
developer using a ZYNC-based board, the experience you gather with Tcl also pays for improving your proficiency in
scripting tools like Vivado.
