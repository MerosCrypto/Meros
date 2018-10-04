#RPC object.
import ../objects/RPCObj

#EventEmitter lib.
import ec_events

#JSON standard lib.
import json

#Shuts down every part of the software.
proc shutdown(rpc: RPC) {.raises: [Exception].} =
    rpc.events.get(
        proc (),
        "system.quit"
    )()

#Handler.
proc `systemModule`*(rpc: RPC, json: JSONNode) {.raises: [Exception].} =
    #Switch based off the method.
    case json["method"].getStr():
        of "quit":
            rpc.shutdown()
