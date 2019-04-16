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
): RPC {.raises: [].} =
    result = RPC()

proc handle*(
    rpc: RPC,
    msg: JSONNode,
    reply: proc (json: JSONNode)
) {.forceCheck: [], async.} =
    discard

proc start*(
    rpc: RPC
) {.forceCheck: [], async.} =
    discard

proc listen*(
    rpc: RPC,
    config: Config
) {.forceCheck: [], async.} =
    discard

proc shutdown*(
    rpc: RPC
) {.raises: [].} =
    discard

proc newGUI*(
    fromMainArg: ptr Channel[string],
    toRPC: ptr Channel[JSONNode],
    toGUI: ptr Channel[JSONNode],
    width: int,
    height: int
) {.raises: [].} =
    discard
