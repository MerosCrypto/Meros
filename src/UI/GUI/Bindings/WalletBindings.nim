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
            proc (key: string) {.raises: [ChannelError].} =
                try:
                    gui.toRPC[].send(%* {
                        "module": "wallet",
                        "method": "set",
                        "args": [
                            key
                        ]
                    })
                except:
                    raise newException(ChannelError, "Couldn't send wallet.set over the channel.")
        )

        #Store the Wallet's Private Key in an element.
        gui.webview.bindProc(
            "Wallet",
            "store",
            proc (fieldsArg: string) {.raises: [ValueError, ChannelError, WebViewError].} =
                try:
                    #Ask for the Wallet info.
                    gui.toRPC[].send(%* {
                        "module": "wallet",
                        "method": "get",
                        "args": []
                    })
                except:
                    raise newException(ChannelError, "Couldn't send wallet.get over the channel.")

                var
                    #Extract the fields.
                    fields: seq[string] = fieldsArg.split(" ")
                    privateKey: string = fields[0]
                    publicKey: string = fields[1]
                    address: string = fields[2]
                    #Create a var for the Wallet.
                    wallet: JSONNode
                try:
                    #Receive the Wallet info.
                    wallet = gui.toGUI[].recv()
                except:
                    raise newException(ChannelError, "Couldn't receive the Wallet info via the channel.")

                #Set the elements.
                if privateKey.len != 0:
                    if gui.webview.eval(
                        "document.getElementById('" & privateKey & "').innerHTML = '" & wallet["privateKey"].getStr() & "';"
                    ) != 0:
                        raise newException(WebViewError, "Couldn't evaluate JS in the WebView.")

                if publicKey.len != 0:
                    if gui.webview.eval(
                        "document.getElementById('" & publicKey & "').innerHTML = '" & wallet["publicKey"].getStr() & "';"
                    ) != 0:
                        raise newException(WebViewError, "Couldn't evaluate JS in the WebView.")

                if address.len != 0:
                    if gui.webview.eval(
                        "document.getElementById('" & address & "').innerHTML = '" & wallet["address"].getStr() & "';"
                    ) != 0:
                        raise newException(WebViewError, "Couldn't evaluate JS in the WebView.")
        )
    except:
        raise newException(WebViewError, "Couldn't bind procs to WebView.")
