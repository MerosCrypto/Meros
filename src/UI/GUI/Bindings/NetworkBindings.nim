#Errors lib.
import ../../../lib/Errors

#GUI object.
import ../objects/GUIObj

#EventEmitter lib.
import mc_events

#WebView lib.
import mc_webview

#String utils standard lib.
import strutils

#JSON standard lib.
import json

#Add the GUI bindings to the GUI.
proc addTo*(gui: GUI) {.raises: [WebViewError].} =
    try:
        #Quit.
        gui.webview.bindProc(
            "network",
            "connect",
            proc (ip: string) {.raises: [OverflowError, ValueError, ChannelError].} =
                var json: JSONNode
                if ip.contains(':'):
                    json = %* {
                        "module": "network",
                        "method": "connect",
                        "args": [
                            ip.split(':')[0],
                            parseInt(ip.split(':')[1])
                        ]
                    }
                else:
                    json = %* {
                        "module": "network",
                        "method": "connect",
                        "args": ip
                    }

                try:
                    #Send the connection info.
                    gui.toRPC[].send(json)
                except:
                    raise newException(ChannelError, "Couldn't send network.connect over the channel.")
        )
    except:
        raise newException(WebViewError, "Couldn't bind procs to WebView.")
