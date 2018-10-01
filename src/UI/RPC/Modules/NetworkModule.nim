#RPC object.
import ../objects/RPCObj

#JSON standard lib.
import json

#Handler.
proc `networkModule`*(rpc: RPC, json: JSONNode) {.raises: [].} =
    discard
