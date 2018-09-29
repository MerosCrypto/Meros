#UI object.
import ../objects/UIObj

#EventEmitter lib.
import ec_events

#WebView lib.
import webview

#String utils standard lib.
import strutils

#Add the UI bindings to the UI.
proc addTo*(ui: UI) {.raises: [Exception].} =
    #Quit.
    ui.webview.bindProcNoArg(
        "UI",
        "quit",
        proc () {.raises: [Exception].} =
            #Close WebView.
            ui.webview.exit()
            #Emit the quit event.
            ui.events.get(proc (), "quit")()
    )

    #Print. If debug isn't defined, this does nothing.
    ui.webview.bindProc(
        "UI",
        "print",
        proc (msg: string) {.raises: [].} =
            when defined(debug):
                echo msg
    )

    #Load a new page.
    ui.webview.bindProc(
        "UI",
        "load",
        proc (pageArg: string) {.raises: [Exception].} =
            #Declare a var for the page.
            var page: string

            #Find out what page to load.
            case pageArg:
                of "main":
                    page = MAIN
                of "send":
                    page = SEND
                of "receive":
                    page = RECEIVE

            #Load the page.
            if ui.webview.eval(
                "document.body.innerHTML = (\"" & page.splitLines().join("\"+\"") & "\");"
            ) != 0:
                raise newException(Exception, "Couldn't evaluate JS in the WebView.")
    )
