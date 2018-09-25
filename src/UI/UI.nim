#Events lib.
import ec_events

#WebView.
import webview

#String utils standard lib.
import strutils

#Constants of the HTML/CSS/JS.
const
    INDEX: string = staticRead("static/index.html")

#UI.
type UI* = ref object of RootObj
    events: EventEmitter
    webview: WebView

#Constructor.
proc newUI*(events: EventEmitter, width: int, height:  int): UI {.raises: [Exception].} =
    result = UI(
        events: events,
        webview: newWebView(
            "Ember Core",
            "",
            width,
            height
        )
    )

    if result.webview.eval(
        "document.write(\r\n" &
        "    \"" & INDEX.splitLines().join("\" +\r\n    \"") & "\"" &
        "\r\n);"
    ) != 0:
        raise newException(Exception, "Couldn't evaluate JS in the WebView.")

#Run function.
proc run*(ui: UI) {.raises: [].} =
    ui.webview.run()

#Destructor.
proc destroy*(ui: UI) {.raises: [].} =
    ui.webview.terminate()
