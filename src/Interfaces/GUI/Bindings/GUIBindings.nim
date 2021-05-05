import json

import ../../../lib/Errors

import ../objects/GUIObj

var carried: CarriedCallback

proc addTo*(
  gui: var GUI,
  poll: CarriedCallback
) {.forceCheck: [].} =
  try:
    gui.webview.bindProc(
      "GUI_quit",
      proc (
        id: cstring,
        jsonArgs: cstring,
        carriedArgs: pointer
      ) {.cdecl, forceCheck: [].} =
        discard cast[ptr GUI](carriedArgs)[].call("system", "quit")
      ,
      addr gui
    )

    #poll function to allow the GUI thread to do something other than WebView.
    carried = poll
    gui.webview.bindProc("GUI_poll", carried.fn, addr carried.carry)

    gui.webview.bindProc(
      "RPC_call",
      proc (
        id: cstring,
        jsonArgs: cstring,
        carriedArgs: pointer
      ) {.cdecl, forceCheck: [].} =
        var args: JSONNode
        try:
          args = parseJSON($jsonArgs)
        except ValueError as e:
          logDebug "Invalid JSON from WebView", json = jsonArgs
          panic("WebView handed invalid JSON to a bound proc: " & e.msg)
        except Exception as e:
          panic("parseJSON raised a Defect: " & e.msg)
        cast[ptr GUI](carriedArgs)[].webview.returnProc(
          id,
          0,
          $cast[ptr GUI](carriedArgs)[].call(args[0].getStr(), args[1].getStr(), args[2])
        )
      ,
      addr gui
    )
  except KeyError as e:
    panic("Couldn't bind the GUI functions to WebView due to a KeyError: " & e.msg)
  except Exception as e:
    panic("Couldn't bind the GUI functions to WebView due to an Exception: " & e.msg)
