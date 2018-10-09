#Errors lib.
import ../../../lib/Errors

#Wallet lib.
import ../../../Wallet/Wallet

#GUI object.
import ../objects/GUIObj

#WebView lib.
import ec_webview

#String utils standard lib.
import strutils

#JSON standard lib.
import json

#Add the Wallet bindings to the GUI.
proc addTo*(gui: GUI) {.raises: [WebViewError].} =
    try:
        #Create a Wallet from a Private Key.
        gui.webview.bindProc(
            "Wallet",
            "create",
            proc (key: string) {.raises: [KeyError, ChannelError, WebViewError].} =
                #Var for the response.
                var wallet: JSONNode
                try:
                    gui.toRPC[].send(%* {
                        "module": "wallet",
                        "method": "set",
                        "args": [
                            key
                        ]
                    })

                    #Receive the Wallet info.
                    wallet = gui.toGUI[].recv()
                except:
                    raise newException(ChannelError, "Couldn't set the Wallet's Private Key.")

                #Set the elements.
                if gui.webview.eval(
                    "document.getElementById('privateKey').innerHTML = '" & wallet["privateKey"].getStr() & "';"
                ) != 0:
                    raise newException(WebViewError, "Couldn't evaluate JS in the WebView.")
                if gui.webview.eval(
                    "document.getElementById('publicKey').innerHTML = '" & wallet["publicKey"].getStr() & "';"
                ) != 0:
                    raise newException(WebViewError, "Couldn't evaluate JS in the WebView.")
                if gui.webview.eval(
                    "document.getElementById('address').innerHTML = '" & wallet["address"].getStr() & "';"
                ) != 0:
                    raise newException(WebViewError, "Couldn't evaluate JS in the WebView.")
        )
    except:
        raise newException(WebViewError, "Couldn't bind procs to WebView.")
