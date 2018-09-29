#Wallet lib.
import ../../Wallet/Wallet

#UI object.
import ../objects/UIObj

#WebView lib.
import webview

#String utils standard lib.
import strutils

#Add the Wallet bindings to the UI.
proc addTo*(ui: UI) {.raises: [Exception].} =
    #Create a Wallet from a Private Key.
    ui.webview.bindProc(
        "Wallet",
        "create",
        proc (key: string) {.raises: [ValueError, Exception].} =
            #If a key was passed, creae a Wallet from it.
            if key.len > 0:
                ui.wallet = newWallet(key)
            #Else, create a new Wallet.
            else:
                ui.wallet = newWallet()
    )

    #Store the Wallet's Private Key in an element.
    ui.webview.bindProc(
        "Wallet",
        "storePrivateKey",
        proc (element: string) {.raises: [Exception].} =
            if ui.webview.eval(
                "document.getElementById('" & element & "').innerHTML = '" & $ui.wallet.privateKey & "';"
            ) != 0:
                raise newException(Exception, "Couldn't evaluate JS in the WebView.")
    )

    #Get the Wallet's Public Key.
    ui.webview.bindProc(
        "Wallet",
        "storePublicKey",
        proc (element: string) {.raises: [Exception].} =
            if ui.webview.eval(
                "document.getElementById('" & element & "').innerHTML = '" & $ui.wallet.publicKey & "';"
            ) != 0:
                raise newException(Exception, "Couldn't evaluate JS in the WebView.")
    )

    #Get the Wallet's Address.
    ui.webview.bindProc(
        "Wallet",
        "storeAddress",
        proc (element: string) {.raises: [Exception].} =
            if ui.webview.eval(
                "document.getElementById('" & element & "').innerHTML = '" & ui.wallet.address & "';"
            ) != 0:
                raise newException(Exception, "Couldn't evaluate JS in the WebView.")
    )
