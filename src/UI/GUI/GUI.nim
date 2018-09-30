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
import webview

#Async standard lib.
import asyncdispatch

#String utils standard lib.
import strutils

#Constructor.
proc newGUI*(events: EventEmitter, width: int, height: int): GUI {.raises: [Exception].} =
    #Create the GUI.
    result = newGUI(
        events,
        newWebView(
            "Ember Core",
            "",
            width,
            height
        )
    )

    #Add the Bindings.
    result.createBindings()

    #Load the main page.
    if result.webview.eval(
        "document.body.innerHTML = (\"" & MAIN.splitLines().join("\"+\"") & "\");"
    ) != 0:
        raise newException(Exception, "Couldn't evaluate JS in the WebView.")

#Run function.
proc run*(ui: GUI) {.raises: [].} =
    ui.webview.run()

#Destructor.
proc destroy*(ui: GUI) {.raises: [].} =
    ui.webview.terminate()
