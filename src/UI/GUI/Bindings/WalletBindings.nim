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
proc addTo*(gui: GUI) {.raises: [Exception].} =
    #Create a Wallet from a Private Key.
    gui.webview.bindProc(
        "Wallet",
        "create",
        proc (key: string) {.raises: [DeadThreadError, Exception].} =
            gui.toRPC[].send(%* {
                "module": "wallet",
                "method": "set",
                "args": [
                    key
                ]
            })
    )

    #Store the Wallet's Private Key in an element.
    gui.webview.bindProc(
        "Wallet",
        "store",
        proc (fieldsArg: string) {.raises: [DeadThreadError, Exception].} =
            #Ask for the Wallet info.
            gui.toRPC[].send(%* {
                "module": "wallet",
                "method": "get",
                "args": []
            })

            var
                #Extract the fields.
                fields: seq[string] = fieldsArg.split(" ")
                privateKey: string = fields[0]
                publicKey: string = fields[1]
                address: string = fields[2]
                #Receive the Wallet info.
                wallet: JSONNode = gui.toGUI[].recv()

            #Set the elements.
            if privateKey.len != 0:
                if gui.webview.eval(
                    "document.getElementById('" & privateKey & "').innerHTML = '" & wallet["privateKey"].getStr() & "';"
                ) != 0:
                    raise newException(Exception, "Couldn't evaluate JS in the WebView.")
            if publicKey.len != 0:
                if gui.webview.eval(
                    "document.getElementById('" & publicKey & "').innerHTML = '" & wallet["publicKey"].getStr() & "';"
                ) != 0:
                    raise newException(Exception, "Couldn't evaluate JS in the WebView.")
            if address.len != 0:
                if gui.webview.eval(
                    "document.getElementById('" & address & "').innerHTML = '" & wallet["address"].getStr() & "';"
                ) != 0:
                    raise newException(Exception, "Couldn't evaluate JS in the WebView.")
    )
