#Errors lib.
import ../../../lib/Errors

#Numerical libs.
import BN
import ../../../lib/Base

#Wallet lib.
import ../../../Wallet/Wallet

#Lattice lib.
import ../../../Database/Lattice/Lattice

#GUI object.
import ../objects/GUIObj

#Events lib.
import ec_events

#Finals lib.
import finals

#WebView lib.
import ec_webview

#String utils standard lib.
import strutils

#JSON standard lib.
import json

#Get the nonce to use with new transactions.
proc getNonce*(gui: GUI): string {.raises: [ChannelError].} =
    #Create a var for the address.
    var address: string
    try:
        #Ask for the Wallet info.
        gui.toRPC[].send(%* {
            "module": "wallet",
            "method": "get",
            "args": []
        })
        #Get the wallet info.
        address = gui.toGUI[].recv()["address"].getStr()
    except:
        raise newException(ChannelError, "Couldn't send wallet.get/get the Wallet info via the channel.")

    try:
        #Ask for the Wallet's height.
        gui.toRPC[].send(%* {
            "module": "lattice",
            "method": "getHeight",
            "args": [
                address
            ]
        })
        #Set the result to the Wallet's height (AKA the next nonce).
        result = gui.toGUI[].recv()["height"].getStr()
    except:
        raise newException(ChannelError, "Couldn't send lattice.getHeight/get the height via the channel.")

#Add the Lattice bindings to the GUI.
proc addTo*(gui: GUI) {.raises: [WebViewError].} =
    try:
        #Send.
        gui.webview.bindProc(
            "Lattice",
            "send",
            proc (dataArg: string) {.raises: [ChannelError].} =
                #Split the data up.
                var data: seq[string] = dataArg.split(" ")

                #Create the Send.
                try:
                    gui.toRPC[].send(%* {
                        "module": "lattice",
                        "method": "send",
                        "args": [
                            data[0],
                            data[1],
                            gui.getNonce()
                        ]
                    })
                except:
                    raise newException(ChannelError, "Couldn't send lattice.send over the channel.")
        )

        #Receive.
        gui.webview.bindProc(
            "Lattice",
            "receive",
            proc (dataArg: string) {.raises: [ChannelError].} =
                #Split the data.
                var data: seq[string] = dataArg.split(" ")

                try:
                    #Create the Receive.
                    gui.toRPC[].send(%* {
                        "module": "lattice",
                        "method": "receive",
                        "args": [
                            data[0],
                            data[1],
                            gui.getNonce()
                        ]
                    })
                except:
                    raise newException(ChannelError, "Couldn't send lattice.receive over the channel.")
        )
    except:
        raise newException(WebViewError, "Couldn't bind procs to WebView.")
