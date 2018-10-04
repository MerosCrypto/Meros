#Errors lib.
import ../../lib/Errors

#BN lib.
import BN

#Import the Wallet lib.
import ../../Wallet/Wallet

#GUI object.
import objects/GUIObj
export GUIObj

#JS Bindings.
import Bindings/Bindings

#Events lib.
import ec_events

#WebView.
import ec_webview

#Async standard lib.
import asyncdispatch

#String utils standard lib.
import strutils

#JSON standard lib.
import json

#Constructor.
proc newGUI*(
    toRPC: ptr Channel[JSONNode],
    toGUI: ptr Channel[JSONNode],
    width: int,
    height: int
) {.thread, raises: [WebViewError].} =
    #Create a var for the GUI.
    var gui: GUI
    try:
        #Create the GUI.
        gui = newGUIObject(
            toRPC,
            toGUI,
            newWebView(
                "Ember Core",
                "",
                width,
                height
            )
        )
    except:
        raise newException(WebViewError, "Couldn't create the WebView.")

    #Add the Bindings.
    gui.createBindings()

    #Load the main page.
    if gui.webview.eval(
        "document.body.innerHTML = (\"" & MAIN.splitLines().join("\"+\"") & "\");"
    ) != 0:
        raise newException(WebViewError, "Couldn't evaluate JS in the WebView.")

    try:
        #Run the GUI.
        gui.webview.run()
    except:
        raise newException(WebViewError, "Couldn't run the WebView.")
