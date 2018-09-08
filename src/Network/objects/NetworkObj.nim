#Import the Server object.
import ServerObj

#Events library.
import ec_events

type Network* = ref object of RootObj
    #Network ID.
    id: int
    #Socket Event Emitter for the sublibraries.
    socketEvents: EventEmitter
    #Server.
    server: Server
    #Node Event Emitter for the node.
    nodeEvents: EventEmitter

#Constructor.
proc newNetworkObj*(
    id: int,
    socketEvents: EventEmitter,
    server: Server,
    nodeEvents: EventEmitter
): Network {.raises: [].} =
    Network(
        id: id,
        socketEvents: socketEvents,
        server: server,
        nodeEvents: nodeEvents
    )

#Getters.
proc getID*(network: Network): int {.raises: [].} =
    network.id
proc getSocketEvents*(network: Network): EventEmitter {.raises: [].} =
    network.socketEvents
proc getServer*(network: Network): Server {.raises: [].} =
    network.server
proc getNodeEvents*(network: Network): EventEmitter {.raises: [].} =
    network.nodeEvents
