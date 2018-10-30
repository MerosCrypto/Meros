#Errors lib.
import ../../../lib/Errors

#Wallet lib.
import ../../../Wallet/Wallet

#EventEmitter lib.
import ec_events

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
        events* {.final.}: EventEmitter
        toRPC* {.final.}: ptr Channel[JSONNode]
        toGUI* {.final.}: ptr Channel[JSONNode]
        server* {.final.}: AsyncSocket
        listening*: bool

#Constructor.
proc newRPCObject*(
    events: EventEmitter,
    toRPC: ptr Channel[JSONNode],
    toGUI: ptr Channel[JSONNode]
): RPC {.raises: [SocketError].} =
    try:
        result = RPC(
            events: events,
            toRPC: toRPC,
            toGUI: toGUI,
            server: newAsyncSocket(),
            listening: true
        )
    except:
        raise newException(SocketError, "Couldn't start the RPC Socket.")
