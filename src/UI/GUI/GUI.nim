#Errors lib.
import ../../lib/Errors

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

#Thread vars needed by loop.
var
    gui: GUI
    fromMain: ptr Channel[string]

#Loop. Called by WebView 10 times a second.
proc loop() {.raises: [ChannelError, WebViewError].} =
    #Get a message if one exists.
    var msg: tuple[dataAvailable: bool, msg: string]
    try:
        msg = fromMain[].tryRecv()
    except:
        raise newException(ChannelError, "The GUI couldn't try to receive data from fromMain.")

    #If there is a message...
    if msg.dataAvailable:
        #Switch on it.
        case msg.msg:
            #If it said to shutdown, shutdown.
            of "shutdown":
                try:
                    gui.webview.exit()
                except:
                    raise newException(WebViewError, "Couldn't shutdown the WebView.")

#Constructor.
proc newGUI*(
    fromMainArg: ptr Channel[string],
    toRPC: ptr Channel[JSONNode],
    toGUI: ptr Channel[JSONNode],
    width: int,
    height: int
) {.raises: [ChannelError, WebViewError].} =
    #Set the fromMain channel.
    fromMain = fromMainArg

    #Create the GUI.
    try:
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
    gui.createBindings(loop)

    #Load the main page.
    if gui.webview.eval(
        "document.body.innerHTML = (\"" & MAIN.splitLines().join("\"+\"") & "\");"
    ) != 0:
        raise newException(WebViewError, "Couldn't evaluate JS in the WebView.")

    try:
        #Schedule a function to start the loop.
        gui.webview.dispatch(
            proc () {.raises: [WebViewError].} =
                if gui.webview.eval(
                    "setInterval(GUI.loop, 100);"
                ) != 0:
                    raise newException(WebViewError, "Couldn't evaluate JS in the WebView.")
        )
        #Run the GUI.
        gui.webview.run()
    except:
        raise newException(WebViewError, "Couldn't run the WebView.")
