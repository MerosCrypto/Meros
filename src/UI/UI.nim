#Import WebView.
import webview

#UI.
type UI* = ref object of RootObj
    webview: WebView

#Constructor.
proc newUI*(width: int, height:  int): UI {.raises: [Exception].} =
    result = UI(
        webview: newWebView("Ember Core", "", width, height)
    )

#Run function.
proc run*(ui: UI) {.raises: [].} =
    ui.webview.run()

#Destructor.
proc destroy*(ui: UI) {.raises: [].} =
    ui.webview.terminate()
