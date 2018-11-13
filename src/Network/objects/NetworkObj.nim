#Import the Clients object.
import ClientsObj

#Events library.
import ec_events

#finals lib.
import finals

#Tables standard lib.
import tables

#Asyncnet standard lib.
import asyncnet

finalsd:
    type Network* = ref object of RootObj
        #Network ID.
        id* {.final.}: uint
        #Protocol version.
        protocol* {.final.}: uint
        #Clients.
        clients*: Clients
        #Server.
        server* {.final.}: AsyncSocket
        #Event Emitter for the Clients/Server.
        subEvents* {.final.}: EventEmitter
        #Event Emitter for the node.
        nodeEvents* {.final.}: EventEmitter

#Constructor.
func newNetworkObj*(
    id: uint,
    protocol: uint,
    clients: Clients,
    server: AsyncSocket,
    subEvents: EventEmitter,
    nodeEvents: EventEmitter
): Network {.raises: [].} =
    result = Network(
        id: id,
        protocol: protocol,
        clients: clients,
        server: server,
        subEvents: subEvents,
        nodeEvents: nodeEvents
    )
    result.ffinalizeID()
    result.ffinalizeProtocol()
    result.ffinalizeServer()
    result.ffinalizeSubEvents()
    result.ffinalizeNodeEvents()
