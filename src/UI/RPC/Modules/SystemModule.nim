#Errors lib.
import ../../../lib/Errors

#RPC object.
import ../objects/RPCObj

#Async standard lib.
import asyncdispatch

#JSON standard lib.
import json

#Shuts down every part of the software.
proc shutdown(
    rpc: RPC,
    reply: proc (
        json: JSONNode
    ) {.raises: [].}
) {.forceCheck: [].} =
    #Reply with an empty object.
    reply(%* {})

    #Quit.
    rpc.functions.system.quit()

#Handler.
proc system*(
    rpc: RPC,
    json: JSONNode,
    reply: proc (
        json: JSONNode
    ) {.raises: [].}
) {.forceCheck: [], async.} =
    #Switch based off the method.
    var methodStr: string
    try:
        methodStr = json["method"].getStr()
    except KeyError:
        reply(%* {
            "error": "No method specified."
        })
        return

    case methodStr:
        of "quit":
            rpc.shutdown(reply)

        else:
            reply(%* {
                "error": "Invalid method."
            })
