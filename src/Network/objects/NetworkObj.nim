#Import the Server object.
import ServerObj

#Events library.
import ec_events

type Network* = ref object of RootObj
    #Socket Event Emitter for the sublibraries.
    socketEvents: EventEmitter
    #Server.
    server: Server
    #Node Event Emitter for the node.
    nodeEvents: EventEmitter

#Constructor.
proc newNetworkObj*(
    socketEvents: EventEmitter,
    server: Server
): Network {.raises: [].} =
    Network(
        socketEvents: socketEvents,
        server: server
    )

#Setter for the nodeEvents var (which updates main).
proc setNodeEvents*(network: Network, ee: EventEmitter): bool {.raises: [].} =
    result = true
    if not network.nodeEvents.isNil:
        return false

    network.nodeEvents = ee
