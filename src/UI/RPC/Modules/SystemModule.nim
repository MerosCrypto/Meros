#RPC object.
import ../objects/RPCObj

#EventEmitter lib.
import ec_events

#JSON standard lib.
import json

#Shutsdown every part of the software.
proc quit*(rpc: RPC) {.raises: [Exception].} =
    rpc.events.get(
        proc (),
        "quit"
    )()

#Handler.
proc `systemModule`*(rpc: RPC, json: JSONNode) {.raises: [Exception].} =
    #Switch based off the method.
    case json["method"].getStr():
        of "quit":
            quit()
