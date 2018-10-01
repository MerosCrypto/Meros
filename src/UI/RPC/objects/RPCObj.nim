#EventEmitter lib.
import ec_events

#Finals lib.
import finals

#RPC object.
finalsd:
    type RPC* = ref object of RootObj
        events* {.final.}: EventEmitter
        toRPC* {.final.}: ptr Channel[string]
        toGUI* {.final.}: ptr Channel[string]
        listening*: bool

#Constructor.
proc newRPCObject*(
    events: EventEmitter,
    toRPC: ptr Channel[string],
    toGUI: ptr Channel[string]
): RPC {.raises: [].} =
    RPC(
        events: events,
        toRPC: toRPC,
        toGUI: toGUI,
        listening: true
    )
