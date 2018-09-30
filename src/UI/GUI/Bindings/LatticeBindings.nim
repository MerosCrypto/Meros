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
import webview

#String utils standard lib.
import strutils

#Add the Lattice bindings to the GUI.
proc addTo*(gui: GUI) {.raises: [Exception].} =
    #Send.
    gui.webview.bindProc(
        "Lattice",
        "send",
        proc (dataArg: string) {.raises: [ValueError, FinalAttributeError, Exception].} =
            var
                #Split the data.
                data: seq[string] = dataArg.split(" ")
                #Extract each argument.
                destination: string = data[0]
                amount: string = data[1]
                nonce: string = data[2]
                #Create the Send.
                send: Send = newSend(
                    destination,
                    newBN(amount),
                    newBN(nonce)
                )
            #Mine the Send.
            send.mine("aa".repeat(64).toBN(16))
            #Sign the Send.
            if not gui.wallet.sign(send):
                raise newException(ValueError, "Failed to sign the GUI's Send.")

            #Add it to the Lattice.
            if not gui.events.get(
                proc (send: Send): bool,
                "send"
            )(
                send
            ):
                raise newException(ValueError, "Failed to add the GUI's Send.")
    )

    #Receive.
    gui.webview.bindProc(
        "Lattice",
        "receive",
        proc (dataArg: string) {.raises: [ValueError, FinalAttributeError, Exception].} =
            var
                #Split the data.
                data: seq[string] = dataArg.split(" ")
                #Extract each argument.
                sender: string = data[0]
                inputNonce: BN = newBN(data[1])
                nonce: BN = newBN(data[2])
                #Create the Receive.
                recv: Receive = newReceive(
                    sender,
                    inputNonce,
                    nonce
                )
            #Sign the Receive.
            gui.wallet.sign(recv)

            #Add it to the Lattice.
            if not gui.events.get(
                proc (recv: Receive): bool,
                "recv"
            )(
                recv
            ):
                raise newException(ValueError, "Failed to add the GUI's Receive.")
    )
