#Wallet lib.
import ../../../Wallet/Wallet

#GUI object.
import ../objects/GUIObj

#WebView lib.
import webview

#Add the Wallet bindings to the GUI.
proc addTo*(gui: GUI) {.raises: [Exception].} =
    #Create a Wallet from a Private Key.
    gui.webview.bindProc(
        "Wallet",
        "create",
        proc (key: string) {.raises: [ValueError, Exception].} =
            #If a key was passed, creae a Wallet from it.
            if key.len > 0:
                gui.wallet = newWallet(key)
            #Else, create a new Wallet.
            else:
                gui.wallet = newWallet()
    )

    #Store the Wallet's Private Key in an element.
    gui.webview.bindProc(
        "Wallet",
        "storePrivateKey",
        proc (element: string) {.raises: [Exception].} =
            if gui.webview.eval(
                "document.getElementById('" & element & "').innerHTML = '" & $gui.wallet.privateKey & "';"
            ) != 0:
                raise newException(Exception, "Couldn't evaluate JS in the WebView.")
    )

    #Store the Wallet's Public Key in an element.
    gui.webview.bindProc(
        "Wallet",
        "storePublicKey",
        proc (element: string) {.raises: [Exception].} =
            if gui.webview.eval(
                "document.getElementById('" & element & "').innerHTML = '" & $gui.wallet.publicKey & "';"
            ) != 0:
                raise newException(Exception, "Couldn't evaluate JS in the WebView.")
    )

    #Store the Wallet's Address in an element.
    gui.webview.bindProc(
        "Wallet",
        "storeAddress",
        proc (element: string) {.raises: [Exception].} =
            if gui.webview.eval(
                "document.getElementById('" & element & "').innerHTML = '" & gui.wallet.address & "';"
            ) != 0:
                raise newException(Exception, "Couldn't evaluate JS in the WebView.")
    )
