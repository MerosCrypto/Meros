#Import the Server object.
import ServerObj

#Events library.
import ec_events

#SetOnce lib.
import SetOnce

type Network* = ref object of RootObj
    #Network ID.
    id*: SetOnce[int]
    #Socket Event Emitter for the sublibraries.
    socketEvents*: SetOnce[EventEmitter]
    #Server.
    server*: SetOnce[Server]
    #Node Event Emitter for the node.
    nodeEvents*: SetOnce[EventEmitter]

#Constructor.
proc newNetworkObj*(
    id: int,
    socketEvents: EventEmitter,
    server: Server,
    nodeEvents: EventEmitter
): Network {.raises: [ValueError].} =
    result = Network()
    result.id.value = id
    result.socketEvents.value = socketEvents
    result.server.value = server
    result.nodeEvents.value = nodeEvents
