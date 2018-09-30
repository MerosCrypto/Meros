#Import the Wallet lib.
import ../../../Wallet/Wallet

#Events lib.
import ec_events

#Finals lib.
import finals

#WebView.
import ec_webview

#Constants of the HTML.
const
    MAIN*: string = staticRead("../static/Main.html")
    SEND*: string = staticRead("../static/Send.html")
    RECEIVE*: string = staticRead("../static/Receive.html")

#GUI.
finalsd:
    type GUI* = ref object of RootObj
        events* {.final.}: EventEmitter
        webview* {.final.}: WebView
        wallet*: Wallet

#Constructor.
proc newGUI*(
    events: EventEmitter,
    webview: WebView
): GUI {.raises: [].} =
    GUI(
        events: events,
        webview: webview
    )
