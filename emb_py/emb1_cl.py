#!/usr/bin/env python
# -*- coding: utf-8 -*-
# R.Wobst, @(#) Aug 17 2015, 10:28:30

"""
Client for emb1.py (see there) with Tkinter.
"""

import thread

from socket import *
from Tkinter import *

PORT = 55667
DELIM = '\n'          # delimiter between data sets
Msglen = 4+len(DELIM)   # lenght of messages

sock = socket(AF_INET, SOCK_STREAM)
sock.connect(('127.0.0.1', PORT))

# send actual state to server

def Change():
    s = [str(v.get()) for v in checkvars]
    try:
        sock.sendall(''.join(s) + DELIM)
    except Exception:
        pass    # message box would be better

# read state from server and display it in checkboxes
# used as thread function

def Update():
    while True:
        state = ''
        while len(state) < Msglen:
            m1 = sock.recv(Msglen - len(state))
            state += m1       # assume that the server won't die

        state = state[:4]   # cut off DELIM

        # modify checkboxes
        for (but,val) in zip(checkbuttons, state):
            if val == '0':
                but.after(0, but.deselect)
            else:
                but.after(0, but.select)

# now construct GUI

root = Tk()

checkbuttons = []   # list of checkbutton objects ...
checkvars = []      # ... and the state variables bound to them

for (nr, label) in enumerate(('Water Flow Valve',
    'Electric Heater',
    'Security Door Lock',
    'Emergency Sirene')):

    var = IntVar()
    checkvars.append(var)
    cbtn = Checkbutton(root, variable = var, command = Change)
    checkbuttons.append(cbtn)
    cbtn.grid(column = 0, row = nr)

    lb = Label(root, text=label)
    lb.grid(column = 1, row = nr, sticky = W)

# first, read the state from server, do that in background
thread.start_new_thread(Update, ())

root.mainloop()
