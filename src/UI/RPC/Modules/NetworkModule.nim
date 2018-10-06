#RPC object.
import ../objects/RPCObj

#JSON standard lib.
import json

#Handler.
func `networkModule`*(rpc: RPC, json: JSONNode) {.raises: [].} =
    discard
