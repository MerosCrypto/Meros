#RPC object.
import ../objects/RPCObj

#EventEmitter lib.
import ec_events

#JSON standard lib.
import json

#Shuts down every part of the software.
proc shutdown(rpc: RPC) {.raises: [].} =
    try:
        rpc.events.get(
            proc (),
            "system.quit"
        )()
    except:
        echo "SAFE SHUTDOWN FAILED!"
        quit(-1)

#Handler.
proc `systemModule`*(rpc: RPC, json: JSONNode) {.raises: [KeyError].} =
    #Switch based off the method.
    case json["method"].getStr():
        of "quit":
            rpc.shutdown()
