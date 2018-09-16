#Import the Clients object.
import ClientsObj

#Events library.
import ec_events

#SetOnce lib.
import SetOnce

#Asyncnet standard lib.
import asyncnet

type Network* = ref object of RootObj
    #Network ID.
    id*: SetOnce[int]
    #Clients.
    clients*: Clients
    #Server.
    server*: SetOnce[AsyncSocket]
    #Event Emitter for the Clients/Server.
    subEvents*: SetOnce[EventEmitter]
    #Event Emitter for the node.
    nodeEvents*: SetOnce[EventEmitter]

#Constructor.
proc newNetworkObj*(
    id: int,
    clients: Clients,
    server: AsyncSocket,
    subEvents: EventEmitter,
    nodeEvents: EventEmitter
): Network {.raises: [ValueError].} =
    result = Network(
        clients: clients
    )
    result.id.value = id
    result.server.value = server
    result.subEvents.value = subEvents
    result.nodeEvents.value = nodeEvents
