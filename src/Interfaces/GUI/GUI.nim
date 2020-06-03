import strformat
import json

import ../../lib/Errors

import objects/GUIObj
export GUI, newGUIObj, call

import Bindings/Bindings

#Create a loop which enables Meros to handle thread communications despite WebView capturing the thread.
proc newLoop(
  gui: GUI,
  fromMain: ptr Channel[string]
): proc () {.raises: [].} {.forceCheck: [].} =
  #Loop. Called by WebView 10 times a second.
  result = proc () {.forceCheck: [].} =
    #Get a message if one exists.
    var msg: tuple[dataAvailable: bool, msg: string]
    try:
      msg = fromMain[].tryRecv()
    except ValueError as e:
      panic("Couldn't try to receive a message from main due to a ValueError: " & e.msg)
    except Exception as e:
      panic("Couldn't try to receive a message from main due to a Exception: " & e.msg)

    #If there is a message, switch on it.
    if msg.dataAvailable:
      case msg.msg:
        of "shutdown":
          gui.webview.exit()
        else:
          panic("Received an unknown message to the WebView thread: " & msg.msg)

proc newGUI*(
  fromMain: ptr Channel[string],
  toRPC: ptr Channel[JSONNode],
  toGUI: ptr Channel[JSONNode],
  width: int,
  height: int
) {.forceCheck: [].} =
  var gui: GUI
  try:
    gui = newGUIObj(toRPC, toGUI, newWebView("Meros", "", width, height))
  except Exception as e:
    panic("Couldn't create the WebView: " & e.msg)

  #Add the Bindings.
  gui.createBindings(newLoop(gui, fromMain))

  #Schedule a function to load the main page/start the loop.
  try:
    gui.webview.dispatch(
      proc () {.forceCheck: [].} =
        #Load the main page.
        var js: string
        try:
          js = &"""
            document.body.innerHTML = `{SEND}`;
          """
        except ValueError as e:
          panic("Couldn't format the JS to load the main page: " & e.msg)

        if gui.webview.eval(js) != 0:
          panic("Couldn't load the main page into the WebView.")

        #Start the loop.
        try:
          js = "setInterval(GUI.loop, 100);"
        except ValueError as e:
          panic("Couldn't format the JS to load the main page: " & e.msg)

        if gui.webview.eval(js) != 0:
          panic("Couldn't start the Nim loop from the WebView.")
    )
  except Exception as e:
    panic("Couldn't dispatch a function to load the main page and start the Nim loop: " & e.msg)

  #Run the GUI.
  gui.webview.run()
