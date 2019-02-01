#Errors lib.
import ../../../lib/Errors

#Wallet lib.
import ../../../Wallet/Wallet

#Main Function Box.
import ../../../MainFunctionBox
#Export it so all modules can access it.
export MainFunctionBox

#Async standard lib.
import asyncdispatch

#Networking standard lib.
import asyncnet

#Finals lib.
import finals

#JSON standard lib.
import json

#RPC object.
finalsd:
    type RPC* = ref object of RootObj
        functions* {.final.}: MainFunctionBox
        toRPC* {.final.}: ptr Channel[JSONNode]
        toGUI* {.final.}: ptr Channel[JSONNode]
        server* {.final.}: AsyncSocket
        clients*: seq[AsyncSocket]
        listening*: bool

#Constructor.
proc newRPCObject*(
    functions: MainFunctionBox,
    toRPC: ptr Channel[JSONNode],
    toGUI: ptr Channel[JSONNode]
): RPC {.raises: [SocketError].} =
    try:
        result = RPC(
            functions: functions,
            toRPC: toRPC,
            toGUI: toGUI,
            server: newAsyncSocket(),
            clients: @[],
            listening: true
        )
        result.ffinalizeFunctions()
        result.ffinalizeToRPC()
        result.ffinalizeToGUI()
        result.ffinalizeServer()
    except:
        raise newException(SocketError, "Couldn't start the RPC Socket.")
