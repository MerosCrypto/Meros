#GUI object.
import ../objects/GUIObj

#EventEmitter lib.
import ec_events

#WebView lib.
import ec_webview

#String utils standard lib.
import strutils

#JSON standard lib.
import json

#Add the GUI bindings to the GUI.
proc addTo*(gui: GUI) {.raises: [Exception].} =
    #Quit.
    gui.webview.bindProcNoArg(
        "GUI",
        "quit",
        proc () {.raises: [Exception].} =
            #Close WebView.
            gui.webview.exit()
            #Emit the quit event.
            gui.toRPC[].send(%* {
                "module": "system",
                "method": "quit",
                "args": []
            })
    )

    #Print. If debug isn't defined, this does nothing.
    gui.webview.bindProc(
        "GUI",
        "print",
        proc (msg: string) {.raises: [].} =
            when defined(debug):
                echo msg
    )

    #Load a new page.
    gui.webview.bindProc(
        "GUI",
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
            if gui.webview.eval(
                "document.body.innerHTML = (\"" & page.splitLines().join("\"+\"") & "\");"
            ) != 0:
                raise newException(Exception, "Couldn't evaluate JS in the WebView.")
    )
