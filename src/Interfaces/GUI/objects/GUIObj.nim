import json

import mc_webview
export mc_webview

import ../../../lib/Errors

#Constants of the HTML.
const
  SEND*: string = staticRead("../static/Send.html")
  DATA*: string = staticRead("../static/Data.html")

type GUI* = ref object
  toRPC: ptr Channel[JSONNode]
  toGUI: ptr Channel[JSONNode]
  webview*: WebView

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
  gui: GUI,
  module: string,
  methodStr: string,
  argsArg: varargs[JSONNode, `%*`]
): JSONNode {.forceCheck: [
  RPCError
].} =
  #Extract the args.
  var args: JSONNode = newJArray()
  for arg in argsArg:
    args.add(arg)

  #Send the call.
  try:
    gui.toRPC[].send(%* {
      "jsonrpc": "2.0",
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

  #If it has an error, throw it.
  if result.hasKey("error"):
    try:
      raise newLoggedException(RPCError, result["error"]["message"].getStr() & " (" & $result["error"]["code"] & ")" & ".")
    except KeyError as e:
      panic("Couldn't get a JSON field despite confirming it exists: " & e.msg)

  #Return the result.
  try:
    result = result["result"]
  except KeyError as e:
    panic("RPC didn't error yet didn't reply with a result either: " & e.msg)
