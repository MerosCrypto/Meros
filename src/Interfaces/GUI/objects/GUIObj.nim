#Errors lib.
import ../../../lib/Errors

#Finals lib.
import finals

#WebView.
import mc_webview
export mc_webview

#JSON standard lib.
import json

#Constants of the HTML.
const
    MAIN*: string = staticRead("../static/Main.html")
    SEND*: string = staticRead("../static/Send.html")

#GUI object.
finalsd:
    type GUI* = ref object
        toRPC: ptr Channel[JSONNode]
        toGUI: ptr Channel[JSONNode]
        webview* {.final.}: WebView

#Constructor.
func newGUIObj*(
    toRPC: ptr Channel[JSONNode],
    toGUI: ptr Channel[JSONNode],
    webview: WebView
): GUI {.forceCheck: [].} =
    result = GUI(
        toRPC: toRPC,
        toGUI: toGUI,
        webview: webview
    )
    result.ffinalizeWebView()

#RPC helper.
proc call*(
    gui: GUI,
    module: string,
    methodStr: string,
    argsArg: varargs[JSONNode, `%*`]
): JSONNode {.forceCheck: [
    RPCError
].} =
    #Extract the args.
    var args: JSONNode = newJArray()
    for arg in argsArg:
        args.add(arg)

    #Send the call.
    try:
        gui.toRPC[].send(%* {
            "jsonrpc": "2.0",
            "method": module & "_" & methodStr,
            "params": args
        })
    except DeadThreadError as e:
        doAssert(false, "Couldn't send data to the RPC due to a DeadThreadError: " & e.msg)
    except Exception as e:
        doAssert(false, "Couldn't send data to the RPC due to an Exception: " & e.msg)

    #If this is quit, don't bother trying to receive the result.
    #It should send a proper response, but we don't need it and recv is blocking.
    if (module == "system") and (methodStr == "quit"):
        return

    #Receive the result.
    try:
        result = gui.toGUI[].recv()
    except ValueError as e:
        doAssert(false, "Couldn't receive data from the RPC due to an ValueError: " & e.msg)
    except Exception as e:
        doAssert(false, "Couldn't receive data from the RPC due to an Exception: " & e.msg)

    #If it has an error, throw it.
    if result.hasKey("error"):
        try:
            raise newException(RPCError, result["error"]["message"].getStr() & " (" & $result["error"]["code"] & ")" & ".")
        except KeyError as e:
            doAssert(false, "Couldn't get a JSON field despite confirming it exists: " & e.msg)

    #Return the result.
    try:
        result = result["result"]
    except KeyError as e:
        doAssert(false, "RPC didn't error yet didn't reply with a result either: " & e.msg)
