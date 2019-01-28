#RPC object.
import ../objects/RPCObj

#Async standard lib.
import asyncdispatch

#JSON standard lib.
import json

#Shuts down every part of the software.
proc shutdown(rpc: RPC, reply: proc (json: JSONNode)) {.raises: [].} =
    try:
        #Reply with an empty object.
        reply(%* {})

        #Quit.
        rpc.events.get(
            proc (),
            "system.quit"
        )()
    except:
        echo "SAFE SHUTDOWN FAILED!"
        quit(-1)

#Handler.
proc systemModule*(
    rpc: RPC,
    json: JSONNode,
    reply: proc (json: JSONNode)
) {.async.} =
    #Switch based off the method.
    case json["method"].getStr():
        of "quit":
            rpc.shutdown(reply)

        else:
            reply(%* {
                "error": "Invalid method."
            })
