#Wallet lib.
import ../../../Wallet/Wallet

#GUI object.
import ../objects/GUIObj

#WebView lib.
import ec_webview

#Add the Wallet bindings to the GUI.
proc addTo*(gui: GUI) {.raises: [Exception].} =
    #Create a Wallet from a Private Key.
    gui.webview.bindProc(
        "Wallet",
        "create",
        proc (key: string) {.raises: [Exception].} =
            #If a key was passed, creae a Wallet from it.
            if key.len > 0:
                gui.toRPC[].send("wallet.set " & key)
            #Else, create a new Wallet.
            else:
                gui.toRPC[].send("wallet.set ")
    )

    #Store the Wallet's Private Key in an element.
    gui.webview.bindProc(
        "Wallet",
        "storePrivateKey",
        proc (element: string) {.raises: [Exception].} =
            #Ask for the Private Key.
            gui.toRPC[].send("wallet.get privatekey")
            #Set the element to it.
            if gui.webview.eval(
                "document.getElementById('" & element & "').innerHTML = '" & gui.toGUI[].recv() & "';"
            ) != 0:
                raise newException(Exception, "Couldn't evaluate JS in the WebView.")
    )

    #Store the Wallet's Public Key in an element.
    gui.webview.bindProc(
        "Wallet",
        "storePublicKey",
        proc (element: string) {.raises: [Exception].} =
            #Ask for the Public Key.
            gui.toRPC[].send("wallet.get publickey")
            #Set the element to it.
            if gui.webview.eval(
                "document.getElementById('" & element & "').innerHTML = '" & gui.toGUI[].recv() & "';"
            ) != 0:
                raise newException(Exception, "Couldn't evaluate JS in the WebView.")
    )

    #Store the Wallet's Address in an element.
    gui.webview.bindProc(
        "Wallet",
        "storeAddress",
        proc (element: string) {.raises: [Exception].} =
            #Ask for the Address.
            gui.toRPC[].send("wallet.get address")
            #Set the element to it.
            if gui.webview.eval(
                "document.getElementById('" & element & "').innerHTML = '" & gui.toGUI[].recv() & "';"
            ) != 0:
                raise newException(Exception, "Couldn't evaluate JS in the WebView.")
    )
