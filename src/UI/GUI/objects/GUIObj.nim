#Import the Wallet lib.
import ../../../Wallet/Wallet

#Events lib.
import ec_events

#Finals lib.
import finals

#WebView.
import ec_webview

#JSON standard lib.
import json

#Constants of the HTML.
const
    MAIN*: string = staticRead("../static/Main.html")
    SEND*: string = staticRead("../static/Send.html")
    RECEIVE*: string = staticRead("../static/Receive.html")

#GUI object.
finalsd:
    type GUI* = ref object of RootObj
        toRPC* {.final.}: ptr Channel[JSONNode]
        toGUI* {.final.}: ptr Channel[JSONNode]
        webview* {.final.}: WebView

#Constructor.
func newGUIObject*(
    toRPC: ptr Channel[JSONNode],
    toGUI: ptr Channel[JSONNode],
    webview: WebView
): GUI {.raises: [].} =
    GUI(
        toRPC: toRPC,
        toGUI: toGUI,
        webview: webview
    )
