import strutils
import strformat
import json

import ../../../lib/Errors

import ../objects/GUIObj

#Add the Wallet bindings to the GUI.
proc addTo*(
  gui: GUI
) {.forceCheck: [].} =
  try:
    gui.webview.bindProc(
      "Personal",
      "send",
      proc (
        data: string
      ) {.forceCheck: [].} =
        var hash: JSONNode
        try:
          hash = gui.call("personal", "send", data.split("|")[0], data.split("|")[1])
        except RPCError as e:
          gui.webview.error("RPC Error", e.msg)
          return

        #Display the hash.
        var js: string
        try:
          js = &"""
            document.getElementById("hash").innerHTML = "{hash.getStr()}";
          """
        except ValueError as e:
          gui.webview.error("Value Error", "Couldn't format the JS to display the hash: " & e.msg)
          return
        if gui.webview.eval(js) != 0:
          gui.webview.error("RPC Error", "Couldn't eval the JS to display the hash.")
          return
    )

    gui.webview.bindProc(
      "Personal",
      "data",
      proc (
        data: string
      ) {.forceCheck: [].} =
        var hash: JSONNode
        try:
          hash = gui.call("personal", "data", data)
        except RPCError as e:
          gui.webview.error("RPC Error", e.msg)
          return

        #Display the hash.
        var js: string
        try:
          js = &"""
            document.getElementById("hash").innerHTML = "{hash.getStr()}";
          """
        except ValueError as e:
          gui.webview.error("Value Error", "Couldn't format the JS to display the hash: " & e.msg)
          return
        if gui.webview.eval(js) != 0:
          gui.webview.error("RPC Error", "Couldn't eval the JS to display the hash.")
          return
    )
  except KeyError as e:
    panic("Couldn't bind the GUI functions to WebView due to a KeyError: " & e.msg)
  except Exception as e:
    panic("Couldn't bind the GUI functions to WebView due to a Exception: " & e.msg)
