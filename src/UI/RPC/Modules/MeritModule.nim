#RPC object.
import ../objects/RPCObj

#JSON standard lib.
import json

#Handler.
func `meritModule`*(
    rpc: RPC,
    json: JSONNode,
    reply: proc (json: JSONNode)
) {.raises: [].} =
    discard
