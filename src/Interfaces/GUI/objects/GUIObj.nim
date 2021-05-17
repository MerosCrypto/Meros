import json

import mc_wry
export mc_wry

import ../../../lib/Errors

#Constants of the HTML.
const DATA*: string = staticRead("../static/Data.html")

type GUI* = object
  fromMain*: ptr Channel[string]
  toRPC: ptr Channel[JSONNode]
  toGUI: ptr Channel[JSONNode]
  webview*: WebView

func newGUI*(
  fromMain: ptr Channel[string],
  toRPC: ptr Channel[JSONNode],
  toGUI: ptr Channel[JSONNode],
  webview: WebView
): GUI {.inline, forceCheck: [].} =
  GUI(
    fromMain: fromMain,
    toRPC: toRPC,
    toGUI: toGUI,
    webview: webview
  )

#RPC helper.
proc call*(
  gui: GUI,
  methodStr: string,
  args: JSONNode
): JSONNode {.cdecl, forceCheck: [].} =
  #Send the call.
  try:
    gui.toRPC[].send(%* {
      "jsonrpc": "2.0",
      "id": 0,
      "method": methodStr,
      "params": args
    })
  except DeadThreadError as e:
    panic("Couldn't send data to the RPC due to a DeadThreadError: " & e.msg)
  except Exception as e:
    panic("Couldn't send data to the RPC due to an Exception: " & e.msg)

  #If this is quit, don't bother trying to receive the result.
  #It should send a proper response, but we don't need it and recv is blocking.
  if methodStr == "system_quit":
    return %* {}

  #Receive the result.
  try:
    result = gui.toGUI[].recv()
  except ValueError as e:
    panic("Couldn't receive data from the RPC due to an ValueError: " & e.msg)
  except Exception as e:
    panic("Couldn't receive data from the RPC due to an Exception: " & e.msg)
