#Number lib.
import BN

#Message/ServerClient objects.
import objects/MessageObj
import objects/ServerClientObj

#Server object.
import objects/ServerObj
#Export the object/constructor/setter.
export ServerObj.Server, newServer

#Events lib.
import ec_events

#Networking standard libs.
import asyncnet, asyncdispatch

#Handles a client.
proc handle(server: Server, client: ServerClient) {.async.} =
    #Get the client ID.
    var id: int = client.getID()

    #While true...
    while true:
        #Read the socket data into the line var.
        var line: string = await client.recvLine()
        #Ignore invalid lines.
        if line.len == 0:
            continue

        #Emit the new Message. If that returns false...
        if not (
            await server.getEventEmitter().get(
                proc (msg: Message): Future[bool],
                "new"
            )(
                newMessage(
                    id,
                    ord(line[0]),
                    ord(line[1]),
                    MessageType(line[2]),
                    line.substr(0, 3),
                    line.substr(4, line.len)
                )
            )
        ):
            #Disconnect the client.
            server.disconnect(id)

#Listen on a port.
proc listen*(server: Server, port: int = 5132) {.async.} =
    #Get the server socket.
    var socket: AsyncSocket = server.getSocket()

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
proc broadcast*(server: Server, msg: string) =
    for client in server.clients():
        asyncCheck client.send(msg)

#Reply to a message.
proc reply*(server: Server, msg: Message, toSend: string) =
    asyncCheck server.getClient(msg.getClient()).send(toSend)

proc disconnect*(server: Server, msg: Message) {.raises: [Exception].} =
    server.disconnect(msg.getClient())
