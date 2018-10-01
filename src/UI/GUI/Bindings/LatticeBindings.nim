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

#Add the Lattice bindings to the GUI.
proc addTo*(gui: GUI) {.raises: [Exception].} =
    #Send.
    gui.webview.bindProc(
        "Lattice",
        "send",
        proc (dataArg: string) {.raises: [DeadThreadError, Exception].} =
            #Split the data.
            var data: seq[string] = dataArg.split(" ")
            gui.toRPC[].send("lattice.receive " & data[0] & data[1] & data[2])
    )

    #Receive.
    gui.webview.bindProc(
        "Lattice",
        "receive",
        proc (dataArg: string) {.raises: [DeadThreadError, Exception].} =
            #Split the data.
            var data: seq[string] = dataArg.split(" ")
            gui.toRPC[].send("lattice.receive " & data[0] & data[1] & data[2])
    )
