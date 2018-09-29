#BN lib.
import BN

#UI object.
import ../objects/UIObj

#WebView lib.
import webview

#String utils standard lib.
import strutils

#Add the Lattice bindings to the UI.
proc addTo*(ui: UI) {.raises: [Exception].} =
    #Send.
    ui.webview.bindProc(
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
    )

    #Receive.
    ui.webview.bindProc(
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
    )
