import uri
import json

import ../../lib/Errors

import objects/GUIObj
export GUI, newGUI, call

import Bindings/Bindings

#Create a poll which enables Meros to handle thread communications despite WebView capturing the thread.
proc newPoll(
  gui: var GUI,
  fromMain: ptr Channel[string]
): CarriedCallback {.forceCheck: [].} =
  result.carry = Carry(
    fromMain: fromMain,
    gui: addr gui
  )

  #Poll. Called by WebView 10 times a second.
  result.fn = proc (
    id: cstring,
    jsonArgs: cstring,
    carriedArgs: pointer
  ) {.cdecl, forceCheck: [].} =
    let carrying: Carry = cast[ptr Carry](carriedArgs)[]

    #Get a message if one exists.
    var msg: tuple[dataAvailable: bool, msg: string]
    try:
      msg = carrying.fromMain[].tryRecv()
    except ValueError as e:
      panic("Couldn't try to receive a message from main due to a ValueError: " & e.msg)
    except Exception as e:
      panic("Couldn't try to receive a message from main due to a Exception: " & e.msg)

    #If there is a message, switch on it.
    if msg.dataAvailable:
      case msg.msg:
        of "quit":
          carrying.gui.webview.terminate()
        else:
          panic("Received an unknown message to the WebView thread: " & msg.msg)

    carrying.gui.webview.returnProc(id, 0, "")

proc newGUI*(
  fromMain: ptr Channel[string],
  toRPC: ptr Channel[JSONNode],
  toGUI: ptr Channel[JSONNode],
  width: int,
  height: int
) {.forceCheck: [].} =
  var gui: GUI
  try:
    gui = newGUI(toRPC, toGUI, newWebView(not defined(merosRelease)))
    if gui.webview.isNil:
      echo "This system doesn't support running Meros with its GUI. Please start Meros with the `--no-gui` flag to continue."
      quit(1)
    gui.webview.setTitle("Meros")
    gui.webview.setSize(cint(width), cint(height), SizeHint.None)
  except Exception as e:
    panic("Couldn't create the WebView: " & e.msg)

  #Load the main page.
  try:
    gui.webview.navigate("data:text/html," & encodeURL(DATA));
  except ValueError as e:
    panic("Couldn't format/evaluate the JS to load the main page: " & e.msg)

  #Add the Bindings.
  gui.createBindings(newPoll(gui, fromMain))

  #Start the loop.
  gui.webview.eval("setInterval(GUI_poll, 5000)")

  #Run the GUI.
  gui.webview.run()
