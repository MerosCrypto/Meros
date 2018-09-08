#Number lib.
import BN

#ServerClient object.
import ServerClientObj

#Events lib.
import ec_events

#Socket standard lib.
import asyncnet

type Server* = ref object of RootObj
    #Server socket.
    socket: AsyncSocket
    #Client count.
    clientCount: int
    #Client list.
    clients: seq[ServerClient]
    #EventEmitter.
    eventEmitter: EventEmitter

#Constructor.
proc newServer*(ee: EventEmitter): Server =
    Server(
        socket: newAsyncSocket(),
        clientCount: 0,
        clients: @[],
        eventEmitter: ee
    )

#Add a client.
proc add*(server: Server, client: AsyncSocket): ServerClient {.raises: [].} =
    #Create a ServerClient around the socket.
    result = newServerClient(
        server.clientCount,
        client
    )

    #Add the new client to the clients.
    server.clients.add(result)
    #Increment the client count.
    inc(server.clientCount)

#disconnect a client.
proc disconnect*(server: Server, id: int) {.raises: [Exception].} =
    for i, c in server.clients:
        if c.getID() == id:
            c.close()
            server.clients.delete(i)
            break

#Getter for the Server socket.
proc getSocket*(server: Server): AsyncSocket {.raises: [].} =
    server.socket

#Gets a specific client.
proc getClient*(server: Server, id: int): ServerClient {.raises: [].} =
    for i in server.clients:
        if i.getID() == id:
            return i

#Iterator over the clients.
iterator clients*(server: Server): AsyncSocket {.raises: [].} =
    for i in server.clients:
        yield i

#Getter for the EventEmitter.
proc getEventEmitter*(server: Server): EventEmitter {.raises: [].} =
    server.eventEmitter
