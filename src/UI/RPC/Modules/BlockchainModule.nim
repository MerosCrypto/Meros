#RPC object.
import ../objects/RPCObj

#JSON standard lib.
import json

#Handler.
proc `blockchainModule`*(rpc: RPC, json: JSONNode) {.raises: [].} =
    discard
