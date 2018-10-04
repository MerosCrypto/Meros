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
proc getNonce*(gui: GUI): string {.raises: [Exception].} =
    echo 1
    #Ask for the Wallet info.
    gui.toRPC[].send(%* {
        "module": "wallet",
        "method": "get",
        "args": []
    })
    echo 2
    #Get the wallet info.
    var address: string = gui.toGUI[].recv()["address"].getStr()
    echo 3

    #Ask for the Wallet's height.
    gui.toRPC[].send(%* {
        "module": "lattice",
        "method": "getHeight",
        "args": [
            address
        ]
    })
    echo 4
    #Set the result to the Wallet's height (AKA the next nonce).
    result = gui.toGUI[].recv()["height"].getStr()
    echo 5

#Add the Lattice bindings to the GUI.
proc addTo*(gui: GUI) {.raises: [Exception].} =
    #Send.
    gui.webview.bindProc(
        "Lattice",
        "send",
        proc (dataArg: string) {.raises: [DeadThreadError, Exception].} =
            #Split the data up.
            var data: seq[string] = dataArg.split(" ")

            #Create the Send.
            gui.toRPC[].send(%* {
                "module": "lattice",
                "method": "send",
                "args": [
                    data[0],
                    data[1],
                    gui.getNonce()
                ]
            })
    )

    #Receive.
    gui.webview.bindProc(
        "Lattice",
        "receive",
        proc (dataArg: string) {.raises: [DeadThreadError, Exception].} =
            #Split the data.
            var data: seq[string] = dataArg.split(" ")

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
    )
