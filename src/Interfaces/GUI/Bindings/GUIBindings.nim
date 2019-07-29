#Errors lib.
import ../../../lib/Errors

#GUI object.
import ../objects/GUIObj

#String format standard lib.
import strformat

#Add the GUI bindings to the GUI.
proc addTo*(
    gui: GUI,
    loop: proc () {.raises: [
        WebViewError
    ].}
) {.forceCheck: [].} =
    try:
        #Quit.
        gui.webview.bindProcNoArg(
            "GUI",
            "quit",
            proc () {.forceCheck: [].} =
                try:
                    discard gui.call("system", "quit")
                except RPCError as e:
                    gui.webview.error("RPC Error", e.msg)
                    return
        )

        #Loop function to allow the GUI thread to do something other than WebView.
        gui.webview.bindProcNoArg(
            "GUI",
            "loop",
            loop
        )

        #Load a new page.
        gui.webview.bindProc(
            "GUI",
            "load",
            proc (
                pageArg: string
            ) {.forceCheck: [].} =
                #Declare a var for the page.
                var page: string

                #Grab the page we're trying to load.
                case pageArg:
                    of "main":
                        page = MAIN
                    of "send":
                        page = SEND
                
                #Format it as a line of JS code.
                try:
                    page = &"document.body.innerHTML = (`{page}`);"
                except ValueError as e:
                    gui.webview.error("Value Error", "Couldn't format the JS to display the main page: " & e.msg)
                    return

                #Load the page.
                if gui.webview.eval(page) != 0:
                    gui.webview.error("RPC Error", "Couldn't eval the JS to load a new page.")
                    return
        )
    except KeyError as e:
        doAssert(false, "Couldn't bind the GUI functions to WebView due to a KeyError: " & e.msg)
    except Exception as e:
        doAssert(false, "Couldn't bind the GUI functions to WebView due to an Exception: " & e.msg)
