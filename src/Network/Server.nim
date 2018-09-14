#Numerical libs.
import BN
import ../lib/Base

#Message/ServerClient objects.
import objects/MessageObj
import objects/ServerClientObj

#Server object.
import objects/ServerObj
#Export the object/constructor/setter.
export ServerObj.Server, newServer

#Events lib.
import ec_events

#SetOnce lib.
import SetOnce

#Networking standard libs.
import asyncnet, asyncdispatch

#Handles a client.
proc handle(server: Server, client: ServerClient) {.async.} =
    #Get the client ID.
    var id: int = client.id

    #While true...
    while true:
        #Read the socket data into the line var.
        var line: string = await client.recvLine()
        #Ignore invalid lines.
        if line.len == 0:
            continue

        #Emit the new Message. If that returns false...
        if not (
            await server.eventEmitter.get(
                proc (msg: Message): Future[bool],
                "new"
            )(
                newMessage(
                    id,
                    ord(line[0]),
                    ord(line[1]),
                    MessageType(line[2]),
                    line.substr(0, 3),
                    line.substr(4, line.len).toBN(253).toString(256)
                )
            )
        ):
            #Disconnect the client.
            server.disconnect(id)
            #Break out of the loop.
            break

#Listen on a port.
proc listen*(server: Server, port: int) {.async.} =
    #Get the server socket.
    var socket: AsyncSocket = server.socket

    #Start listening.
    socket.setSockOpt(OptReuseAddr, true)
    socket.bindAddr(Port(port))
    socket.listen()

    #Accept new connections infinitely.
    while true:
        var client: AsyncSocket = await socket.accept()

        #Handle the new client.
        asyncCheck server.handle(
            server.add(client)
        )

#Sends a message to all clients.
proc broadcast*(server: Server, msg: string) {.raises: [Exception].} =
    for client in server.clients():
        asyncCheck client.send(msg)

#Reply to a message.
proc reply*(server: Server, msg: Message, toSend: string) {.raises: [Exception].} =
    asyncCheck server.getClient(msg.client).send(toSend)

proc disconnect*(server: Server, msg: Message) {.raises: [Exception].} =
    server.disconnect(msg.client)
