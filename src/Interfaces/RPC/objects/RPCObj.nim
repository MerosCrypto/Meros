#Errors lib.
import ../../../lib/Errors

#Finals lib.
import finals

#Macros standard lib.
import macros

#Async standard lib.
import asyncdispatch
export asyncdispatch

#Networking standard lib.
import asyncnet

#Tables standard lib.
import tables
export tables

#JSON standard lib.
import json
export json

#RPC object.
finalsd:
    type
        RPCFunction = proc (
            res: var JSONNode,
            params: JSONNode
        ): Future[void]

        RPCFunctions* = Table[string, RPCFunction]

        RPC* = ref object
            functions: RPCFunctions
            toRPC* {.final.}: ptr Channel[JSONNode]
            toGUI* {.final.}: ptr Channel[JSONNode]
            server* {.final.}: AsyncSocket

#RPCFunctions constructor.
macro newRPCFunctions*(
    routes: untyped
): untyped =
    #Create a toTable call.
    result = newNimNode(nnkAsgn).add(
        newIdentDefs(
            ident("result"),
            newCall(
                ident("toTable")
            ).add(
                newNimNode(nnkTableConstr)
            )
        )
    )

    #Add each route.
    for route in routes:
        #Make sure they're closures.
        route[1].addPragma(ident("closure"))

        #Make sure they're async.
        var async: bool = false
        for pragma in route[1][4]:
            if (pragma.kind == nnkIdent) and (pragma.strVal == "async"):
                async = true
        if not async:
            route[1].addPragma(ident("async"))
            route[1][3][0] = newNimNode(nnkBracketExpr).add(
                ident("Future"),
                ident("void")
            )

        result[0][2][1].add(
            newNimNode(nnkExprColonExpr).add(
                route[0],
                route[1]
            )
        )

#Combine multiple RPCFunctions together.
proc merge*(
    rpcs: varargs[
        tuple[prefix: string, rpc: RPCFunctions]
    ]
): RPCFunctions {.forceCheck: [].} =
    result = initTable[string, RPCFunction]()

    for rpc in rpcs:
        for key in rpc.rpc.keys():
            try:
                result[rpc.prefix & key] = rpc.rpc[key]
            except KeyError as e:
                doAssert(false, "Couldn't get a value from the table despiting getting the key from .keys(): " & e.msg)

#RPC Object Constructor.
proc newRPCObj*(
    functions: RPCFunctions,
    toRPC: ptr Channel[JSONNode],
    toGUI: ptr Channel[JSONNode]
): RPC {.forceCheck: [].} =
    result = RPC(
        functions: functions,
        toRPC: toRPC,
        toGUI: toGUI
    )
    result.ffinalizeToRPC()
    result.ffinalizeToGUI()
