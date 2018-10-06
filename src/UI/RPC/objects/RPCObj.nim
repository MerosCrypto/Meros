#Wallet lib.
import ../../../Wallet/Wallet

#EventEmitter lib.
import ec_events

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
        wallet*: Wallet
        listening*: bool

#Constructor.
func newRPCObject*(
    events: EventEmitter,
    toRPC: ptr Channel[JSONNode],
    toGUI: ptr Channel[JSONNode]
): RPC {.raises: [].} =
    RPC(
        events: events,
        toRPC: toRPC,
        toGUI: toGUI,
        listening: true
    )
