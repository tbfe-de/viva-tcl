#!/usr/bin/env python
# -*- coding: utf-8 -*-
# R.Wobst, @(#) Aug 17 2015, 10:45:13

"""
Client for emb1.py (see there) with wxPython.
"""

import thread

from socket import *
import wx

PORT = 55667
DELIM = '\n'          # delimiter between data sets
Msglen = 4+len(DELIM)   # lenght of messages

sock = socket(AF_INET, SOCK_STREAM)
sock.connect(('127.0.0.1', PORT))

# now construct GUI

class ClientGUI(wx.Frame):
    def __init__(self):
        wx.Frame.__init__(self, None, title = 'emb1')

        # the main panel because of TAB traversal
        panel = wx.Panel(self)

        vbox = wx.BoxSizer(wx.VERTICAL)

        self.checkbuttons = []   # list of checkbutton objects ...

        for label in ('&Water Flow Valve',
            'Electric &Heater',
            'Security &Door Lock',
            'Emergency &Sirene'):

            cbtn = wx.CheckBox(panel, label = label)
            self.Bind(wx.EVT_CHECKBOX, self.OnChange, cbtn)
            self.checkbuttons.append(cbtn)
            vbox.Add(cbtn)

        qb = wx.Button(panel, label = '&Quit')
        self.Bind(wx.EVT_BUTTON, self.OnCancel, qb)
        vbox.Add(qb, flag = wx.ALIGN_RIGHT)

        panel.SetSizerAndFit(vbox)
        self.SetClientSize(panel.GetSize())
        self.Show()

        # first, read the state from server, do that in background
        thread.start_new_thread(self.Update, ())

    ## @brief Quit button: exit

    def OnCancel(self, event):
        self.Close()

    ## @brief send actual state to server

    def OnChange(self, event):
        s = [str(int(cb.GetValue())) for cb in self.checkbuttons]
        try:
            sock.sendall(''.join(s) + DELIM)
        except Exception:
            pass    # message box would be better

    ## @brief set new checkbutton values
    #
    # @param state - new state

    def SetState(self, state):
        # modify checkboxes
        self.Disable()
        for (but,val) in zip(self.checkbuttons, state):
            but.SetValue(val == '1')
        self.Enable()

    # read state from server and display it in checkboxes
    # used as thread function

    def Update(self):
        while True:
            state = ''
            while len(state) < Msglen:
                m1 = sock.recv(Msglen - len(state))
                state += m1       # assume that the server won't die

            state = state[:4]   # cut off DELIM
            wx.CallAfter(self.SetState, state)

app = wx.App(False)
ClientGUI()
app.MainLoop()
