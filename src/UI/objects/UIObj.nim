#Import the Wallet lib.
import ../../Wallet/Wallet

#Events lib.
import ec_events

#Finals lib.
import finals

#WebView.
import webview

#Constants of the HTML.
const
    MAIN*: string = staticRead("../static/Main.html")
    SEND*: string = staticRead("../static/Send.html")
    RECEIVE*: string = staticRead("../static/Receive.html")

#UI.
finalsd:
    type UI* = ref object of RootObj
        events* {.final.}: EventEmitter
        webview* {.final.}: WebView
        wallet*: Wallet

#Constructor.
proc newUI*(
    events: EventEmitter,
    webview: WebView
): UI {.raises: [].} =
    UI(
        events: events,
        webview: webview
    )
