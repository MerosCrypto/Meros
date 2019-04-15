#Provide RPC objects/fake RPC procs so main compiles.
import ../lib/Errors

import ../objects/ConfigObj

import RPC/objects/RPCObj
export RPCObj

import asyncdispatch
import asyncnet

import json

#Constructor.
proc newRPC*(
    functions: GlobalFunctionBox,
    toRPC: ptr Channel[JSONNode],
    toGUI: ptr Channel[JSONNode]
): RPC {.raises: [SocketError].} =
    newRPCObject(
        functions,
        toRPC,
        toGUI
    )

proc handle*(
    rpc: RPC,
    msg: JSONNode,
    reply: proc (json: JSONNode)
) {.async.} =
    discard

proc start*(
    rpc: RPC
) {.async.} =
    discard

proc handle*(
    rpc: RPC,
    client: AsyncSocket
) {.async.} =
    discard

proc listen*(
    rpc: RPC,
    config: Config
) {.async.} =
    discard

proc shutdown*(
    rpc: RPC
) {.raises: [
    AsyncError
].} =
    discard
