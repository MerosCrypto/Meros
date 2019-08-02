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
            res: JSONNode,
            params: JSONNode
        ): Future[void]

        RPCFunctions* = Table[string, RPCFunction]

        RPC* = ref object
            alive*: bool

            functions*: RPCFunctions
            quit*: proc () {.raises: [].}

            toRPC* {.final.}: ptr Channel[JSONNode]
            toGUI* {.final.}: ptr Channel[JSONNode]

            server* {.final.}: AsyncSocket
            clients*: seq[AsyncSocket]

#RPCFunctions constructor.
macro newRPCFunctions*(
    routes: untyped
): untyped =
    #Create a toTable call.
    result = newNimNode(nnkAsgn).add(
        ident("result"),
        newCall(
            ident("toTable")
        ).add(
            newNimNode(nnkTableConstr)
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

        result[1][1].add(
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
): RPCFunctions {.raises: [].} =
    result = initTable[string, RPCFunction]()

    for rpc in rpcs:
        for key in rpc.rpc.keys():
            try:
                result[rpc.prefix & key] = rpc.rpc[key]
            except KeyError as e:
                doAssert(false, "Couldn't get a value from the table despiting getting the key from .keys(): " & e.msg)
            except Exception as e:
                doAssert(false, "Couldn't set a value in a table: " & e.msg)

#RPC Object Constructor.
proc newRPCObj*(
    functions: RPCFunctions,
    quit: proc () {.raises: [].},
    toRPC: ptr Channel[JSONNode],
    toGUI: ptr Channel[JSONNode]
): RPC {.forceCheck: [].} =
    result = RPC(
        alive: true,

        functions: functions,
        quit: quit,

        toRPC: toRPC,
        toGUI: toGUI
    )
    result.ffinalizeToRPC()
    result.ffinalizeToGUI()
