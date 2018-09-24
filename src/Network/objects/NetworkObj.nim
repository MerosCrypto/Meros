#Import the Clients object.
import ClientsObj

#Events library.
import ec_events

#finals lib.
import finals

#Asyncnet standard lib.
import asyncnet

finals:
    type Network* = ref object of RootObj
        #Network ID.
        id* {.final.}: int
        #Clients.
        clients*: Clients
        #Server.
        server* {.final.}: AsyncSocket
        #Event Emitter for the Clients/Server.
        subEvents* {.final.}: EventEmitter
        #Event Emitter for the node.
        nodeEvents* {.final.}: EventEmitter

#Constructor.
proc newNetworkObj*(
    id: int,
    clients: Clients,
    server: AsyncSocket,
    subEvents: EventEmitter,
    nodeEvents: EventEmitter
): Network {.raises: [].} =
    result = Network(
        id: id,
        clients: clients,
        server: server,
        subEvents: subEvents,
        nodeEvents: nodeEvents
    )
