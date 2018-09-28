#BN lib.
import BN

#Import the Wallet lib.
import ../Wallet/Wallet

#Events lib.
import ec_events

#WebView.
import webview

#String utils standard lib.
import strutils

#Constants of the HTML/CSS/JS.
const
    MAIN: string = staticRead("static/Main.html")
    SEND: string = staticRead("static/Send.html")
    RECEIVE: string = staticRead("static/Receive.html")

#UI.
type UI* = ref object of RootObj
    events: EventEmitter
    webview: WebView
    wallet: Wallet

#Constructor.
proc newUI*(events: EventEmitter, width: int, height: int): UI {.raises: [Exception].} =
    #Create the UI.
    var ui: UI = UI(
        events: events,
        webview: newWebView(
            "Ember Core",
            "",
            width,
            height
        )
    )

    #Define the JS functions.
    ui.webview.bindProcNoArg(
        "ui",
        "quit",
        proc () {.raises: [Exception].} =
            #Close WebView.
            ui.webview.exit()
            #Emit the quit event.
            ui.events.get(proc (), "quit")()
    )

    ui.webview.bindProc(
        "ui",
        "print",
        proc (msg: string) {.raises: [].} =
            echo msg
    )

    ui.webview.bindProc(
        "ui",
        "load",
        proc (page: string) {.raises: [].} =
            discard
    )

    ui.webview.bindProc(
        "ui",
        "setPrivateKey",
        proc (key: string) {.raises: [ValueError, Exception].} =
            #If the key exists...
            if key.len > 0:
                #Create a wallet from it.
                ui.wallet = newWallet(key)
            #Else...
            else:
                #Create a new wallet.
                ui.wallet = newWallet()

            echo ui.wallet.privateKey

            #Fill in the Wallet info.
            if ui.webview.eval("document.getElementById('privateKey').innerHTML = '" & $ui.wallet.privateKey & "';") != 0:
                raise newException(Exception, "Couldn't evaluate JS in the WebView.")
            if ui.webview.eval("document.getElementById('publicKey').innerHTML = '" & $ui.wallet.publicKey & "';") != 0:
                raise newException(Exception, "Couldn't evaluate JS in the WebView.")
            if ui.webview.eval("document.getElementById('address').innerHTML = '" & ui.wallet.address & "';") != 0:
                raise newException(Exception, "Couldn't evaluate JS in the WebView.")
    )

    ui.webview.bindProc(
        "ui",
        "send",
        proc (dataArg: string) {.raises: [].} =
            var
                data: seq[string] = dataArg.split(" ")
                destination: string = data[0]
                amount: string = data[1]
                nonce: string = data[2]
    )

    ui.webview.bindProc(
        "ui",
        "recv",
        proc (dataArg: string) {.raises: [].} =
            var
                data: seq[string] = dataArg.split(" ")
                sender: string = data[0]
                inputNonce: BN = newBN(data[1])
                nonce: BN = newBN(data[2])
    )

    #Load the page.
    if ui.webview.eval(
        "document.body.innerHTML = (\"" & MAIN.splitLines().join("\"+\"") & "\");"
    ) != 0:
        raise newException(Exception, "Couldn't evaluate JS in the WebView.")

    #Set the result var to the UI.
    result = ui

#Run function.
proc run*(ui: UI) {.raises: [].} =
    ui.webview.run()

#Destructor.
proc destroy*(ui: UI) {.raises: [].} =
    ui.webview.terminate()
