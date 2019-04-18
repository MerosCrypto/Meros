#Errors lib.
import ../../../lib/Errors

#Global Function Box object.
import ../../../objects/GlobalFunctionBoxObj
#Export it so all modules can access it.
export GlobalFunctionBox

#Finals lib.
import finals

#Macros standard lib.
import macros

#Async standard lib.
import asyncdispatch

#Networking standard lib.
import asyncnet

#JSON standard lib.
import json

#RPC object.
finalsd:
    type
        RPCSocketClient* = ref object
            id* {.final.}: int
            socket* {.final.}: AsyncSocket

        RPC* = ref object
            functions* {.final.}: GlobalFunctionBox
            toRPC* {.final.}: ptr Channel[JSONNode]
            toGUI* {.final.}: ptr Channel[JSONNode]
            server* {.final.}: AsyncSocket
            clients*: seq[RPCSocketClient]
            listening*: bool

#Constructors.
proc newRPCSocketClient*(
    id: int,
    socket: AsyncSocket
): RPCSocketClient {.forceCheck: [].} =
    result = RPCSocketClient(
        id: id,
        socket: socket
    )
    result.ffinalizeID()
    result.ffinalizeSocket()

proc newRPCObj*(
    functions: GlobalFunctionBox,
    toRPC: ptr Channel[JSONNode],
    toGUI: ptr Channel[JSONNode]
): RPC {.forceCheck: [].} =
    result = RPC(
        functions: functions,
        toRPC: toRPC,
        toGUI: toGUI,
        clients: @[],
        listening: true
    )
    result.ffinalizeFunctions()
    result.ffinalizeToRPC()
    result.ffinalizeToGUI()
    result.ffinalizeServer()

#Macro to shorten returning errors when one occurs.
macro returnError*(): untyped =
    newStmtList(
        newNimNode(nnkReturnStmt).add(
            newNimNode(nnkPrefix).add(
                newIdentNode("%*"),
                newNimNode(nnkTableConstr).add(
                    newNimNode(nnkExprColonExpr).add(
                        newStrLitNode("error"),
                        newNimNode(nnkDotExpr).add(
                            newIdentNode("e"),
                            newIdentNode("msg")
                        )
                    )
                )
            )
        )
    )
