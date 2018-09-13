#Number lib.
import BN

#ServerClient object.
import ServerClientObj

#Events lib.
import ec_events

#SetOnce lib.
import SetOnce

#Socket standard lib.
import asyncnet

type Server* = ref object of RootObj
    #Server socket.
    socket*: SetOnce[AsyncSocket]
    #Client count.
    clientCount: int
    #Client list.
    clients: seq[ServerClient]
    #EventEmitter.
    eventEmitter*: SetOnce[EventEmitter]

#Constructor.
proc newServer*(ee: EventEmitter): Server {.raises: [OSError, ValueError, Exception].} =
    result = Server(
        clientCount: 0,
        clients: @[]
    )
    result.socket.value = newAsyncSocket()
    result.eventEmitter.value = ee

#Add a client.
proc add*(server: Server, client: AsyncSocket): ServerClient {.raises: [ValueError].} =
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
        if c.id == id:
            c.close()
            server.clients.delete(i)
            break

#Gets a specific client.
proc getClient*(server: Server, id: int): ServerClient {.raises: [].} =
    for i in server.clients:
        if i.id == id:
            return i

#Iterator over the clients.
iterator clients*(server: Server): AsyncSocket {.raises: [].} =
    for i in server.clients:
        yield i
