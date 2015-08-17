#!/usr/bin/env python
# -*- coding: utf-8 -*-
# R.Wobst, @(#) Aug 17 2015, 10:52:20

# Python version of server emb1.tcl.
# Clients receive their state as 4 chars '0' or '1' followed by DELIM and send
# it in this format if changed.
#
# In addition, the server may be restarted immediately after abort (normally
# blocked by socket reuse timeout), and the server exits after the last client
# was closed.

# The state is intentionally not stored in a file.

from socket import *
import time
import thread

PORT = 55667            # socket port
PINFILE = 'port_pins'   # name of state file
DELAY = 0.1             # polling time (in seconds)

DELIM = '\n'            # delimiter between data sets

Msglen = 4+len(DELIM)   # lenght of messages

s = socket(AF_INET, SOCK_STREAM)
s.setsockopt(SOL_SOCKET, SO_REUSEADDR, 1)
s.bind(('0.0.0.0', PORT))            # bind all interfaces to PORT
s.listen(2)

ClLst = []      # list of client socket objects

## @brief context manager for simpler handling of locking mechanism
#
# Also release lock if exception is raised, lock instance is local.

class Lock:
    def __init__(self):
        self.glock = thread.allocate_lock()
    def __enter__(self):
        self.glock.acquire()
        return self
    def __exit__(self, _a, _b, _c):
        self.glock.release()
        return False     # mind exceptions

# global context manager instance
lockctx = Lock()

## @brief receiver thread function
#
# Receives Msglen bytes calls Update, handles client list
#
# @param cl - socket object
# @param add - socket address object - tuple (IP add, portnr)

def Receive(cl, add):
    while True:
        msg = ''
        # read Msglen bytes, might be in portions
        while len(msg) < Msglen:
            try:
                m1 = cl.recv(Msglen - len(msg))
            except Exception:
                m1 = None

            if not m1:      # socket closed
                print "client closed:", add
                cl.close()

                with lockctx:
                    ClLst.remove(cl)

                #if not ClLst:
                #    print "server exit"
                #    os._exit(0)     # exit process

                return  # exit thread

            msg += m1

        Update(msg)

## @brief update state file and clients
#
# @param state - state with DELIM appended

def Update(state):
    with lockctx:
        with open(PINFILE, 'wb') as fd:
            fd.write(state+DELIM)

        # sync other clients thread-safe
        for cl_ in ClLst:
            try:
                cl_.sendall(state)
            except Exception:
                pass

## @brief file observer, thread function
#
# If the state in PINFILE changes, all clients are updated.

def FileObserver():
    global state

    while True:
        with lockctx:
            with open(PINFILE, 'rb') as fd:
                newstate = fd.read().rstrip('\r\n') + DELIM   # accept all formats

        if newstate != state:
            state = newstate
            Update(state)

        time.sleep(DELAY)

# *** server loop

state = None    # global var
thread.start_new_thread(FileObserver, ())

while True:
    print "waiting for connection ..."
    (cl, add) = s.accept()

    with lockctx:
        ClLst.append(cl)
        try:
            cl.sendall(state)
        except Exception:
            pass

    print "connected:", add
    thread.start_new_thread(Receive, (cl, add))
