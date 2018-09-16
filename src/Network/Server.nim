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
    var
        #Get the client ID.
        id: int = client.id
        #Define the loop vars outside of the loop.
        header: string
        size: int
        line: string

    while true:
        #Receive the header.
        header = await client.recv(4)
        #Verify the length.
        if header.len != 4:
            continue
        #Define the size.
        size = ord(header[3])
        #While the size is 255 bytes (signifying it's even bigger than that)...
        while ord(header[header.len - 1]) == 255:
            #Get a new byte.
            header &= await client.recv(1)
            #Add it to the size.
            size += ord(header[header.len - 1])
        #Get the line.
        line = await client.recv(size)
        #Verify the length.
        if line.len != size:
            continue

        #Emit the new Message. If that returns false...
        if not (
            await server.eventEmitter.get(
                proc (msg: Message): Future[bool],
                "new"
            )(
                newMessage(
                    id,
                    ord(header[0]),
                    ord(header[1]),
                    MessageType(header[2]),
                    header,
                    line
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
