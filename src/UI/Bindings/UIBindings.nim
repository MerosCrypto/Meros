#UI object.
import ../objects/UIObj

#EventEmitter lib.
import ec_events

#WebView lib.
import webview

#Add the UI bindings to the UI.
proc addTo*(ui: UI) {.raises: [Exception].} =
    #Quit.
    ui.webview.bindProcNoArg(
        "ui",
        "quit",
        proc () {.raises: [Exception].} =
            #Close WebView.
            ui.webview.exit()
            #Emit the quit event.
            ui.events.get(proc (), "quit")()
    )

    #Print. If debug isn't defined, this does nothing.
    ui.webview.bindProc(
        "ui",
        "print",
        proc (msg: string) {.raises: [].} =
            when defined(debug):
                echo msg
    )

    #Load a new page.
    ui.webview.bindProc(
        "ui",
        "load",
        proc (page: string) {.raises: [].} =
            discard
    )
