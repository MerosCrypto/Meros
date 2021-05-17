import json

import ../../lib/Errors

import objects/GUIObj

var gui: GUI
proc guiRPC(
  req: RpcRequest
): cstring {.cdecl.} =
  case $req.rpc_method:
    #Used to give this thread a chance to execute Nim code.
    of "gui_poll":
      #Get a message if one exists.
      var msg: tuple[dataAvailable: bool, msg: string]
      try:
        msg = gui.fromMain[].tryRecv()
      except ValueError as e:
        panic("Couldn't try to receive a message from main due to a ValueError: " & e.msg)
      except Exception as e:
        panic("Couldn't try to receive a message from main due to a Exception: " & e.msg)

      #If there is a message, switch on it.
      if msg.dataAvailable:
        case msg.msg:
          of "quit":
            gui.webview.terminate()
          else:
            panic("Received an unknown message to the WebView thread: " & msg.msg)
      return "{}"
    else:
      var params: JSONNode = parseJSON($req.params)
      if params.len == 0:
        params.add(%* {})
      return $gui.call($req.rpc_method, params[0])

proc newGUI*(
  fromMain: ptr Channel[string],
  toRPC: ptr Channel[JSONNode],
  toGUI: ptr Channel[JSONNode],
  width: int,
  height: int
) {.forceCheck: [].} =
  #Create the GUI.
  try:
    gui = newGUI(fromMain, toRPC, toGUI, newWebView("Meros", "data:text/html,\r\n" & DATA, guiRPC))
  except Exception as e:
    panic("Couldn't create the WebView: " & e.msg)

  #Make sure it's valid.
  if not gui.webview.valid:
    echo "This system doesn't support running Meros with its GUI. Please start Meros with the `--no-gui` flag to continue."
    quit(1)

  #Run it.
  gui.webview.run()
