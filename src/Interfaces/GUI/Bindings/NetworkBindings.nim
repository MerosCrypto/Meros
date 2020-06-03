import strutils
import json

import ../../../lib/Errors

import ../objects/GUIObj

proc addTo*(
  gui: GUI
) {.forceCheck: [].} =
  try:
    gui.webview.bindProc(
      "network",
      "connect",
      proc (
        ip: string
      ) {.forceCheck: [].} =
        try:
          if ip.contains(':'):
            discard gui.call(
              "network",
              "connect",
              ip.split(':')[0],
              parseInt(ip.split(':')[1])
            )
          else:
            discard gui.call("network", "connect", ip)
        except ValueError as e:
          gui.webview.error("Value Error", "Invalid port number: " & e.msg)
          return
        except RPCError as e:
          gui.webview.error("RPC Error", e.msg)
          return
    )
  except KeyError as e:
    panic("Couldn't bind the GUI functions to WebView due to a KeyError: " & e.msg)
  except Exception as e:
    panic("Couldn't bind the GUI functions to WebView due to a Exception: " & e.msg)
