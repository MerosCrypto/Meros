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
        proc (dataArg: string) {.raises: [].} =
            var
                #Split the data.
                data: seq[string] = dataArg.split(" ")
                #Extract each argument.
                destination: string = data[0]
                amount: string = data[1]
                nonce: string = data[2]

            echo dataArg
    )

    #Receive.
    gui.webview.bindProc(
        "Lattice",
        "receive",
        proc (dataArg: string) {.raises: [].} =
            var
                #Split the data.
                data: seq[string] = dataArg.split(" ")
                #Extract each argument.
                sender: string = data[0]
                inputNonce: BN = newBN(data[1])
                nonce: BN = newBN(data[2])

            echo dataArg
    )
