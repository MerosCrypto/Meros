import json

import mc_webview
export mc_webview

import ../../../lib/Errors

#Constants of the HTML.
const DATA*: string = staticRead("../static/Data.html")

type
  GUIObj* = object
    toRPC: ptr Channel[JSONNode]
    toGUI: ptr Channel[JSONNode]
    webview*: WebView

  GUI* = ref GUIObj

  Carry* = object
    fromMain*: ptr Channel[string]
    gui*: ptr GUIObj

  CarriedCallback* = object
    fn*: proc (
      id: cstring,
      jsonArgs: cstring,
      carriedArgs: pointer
    ) {.cdecl, raises: [].}
    carry*: Carry

func newGUIObj*(
  toRPC: ptr Channel[JSONNode],
  toGUI: ptr Channel[JSONNode],
  webview: WebView
): GUI {.inline, forceCheck: [].} =
  GUI(
    toRPC: toRPC,
    toGUI: toGUI,
    webview: webview
  )

#RPC helper.
proc call*(
  gui: GUIObj,
  module: string,
  methodStr: string,
  args: JSONNode = %* {}
): JSONNode {.cdecl, forceCheck: [].} =
  #Send the call.
  try:
    gui.toRPC[].send(%* {
      "jsonrpc": "2.0",
      "id": 0,
      "method": module & "_" & methodStr,
      "params": args
    })
  except DeadThreadError as e:
    panic("Couldn't send data to the RPC due to a DeadThreadError: " & e.msg)
  except Exception as e:
    panic("Couldn't send data to the RPC due to an Exception: " & e.msg)

  #If this is quit, don't bother trying to receive the result.
  #It should send a proper response, but we don't need it and recv is blocking.
  if (module == "system") and (methodStr == "quit"):
    return

  #Receive the result.
  try:
    result = gui.toGUI[].recv()
  except ValueError as e:
    panic("Couldn't receive data from the RPC due to an ValueError: " & e.msg)
  except Exception as e:
    panic("Couldn't receive data from the RPC due to an Exception: " & e.msg)
