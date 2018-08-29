#Numerical libs.
import ../../lib/BN

#Message/ServerClient objects.
import objects/Message
import objects/ServerClient

#Networking standard libs.
import asyncnet, asyncdispatch

var
    #Server socket.
    server: AsyncSocket = newAsyncSocket()
    #Client count/client list.
    clientCount: int = 0
    clients: seq[ServerClient] = @[]
    #Unprocessed messages.
    unprocessed: seq[Message] = @[]

#Handles a client.
proc handle(client: ServerClient) {.async.} =
    #Get the client ID.
    var id: int = client.getID()

    #While true...
    while true:
        #Read the socket data into the line var.
        var line: string = await client.recvLine()
        #Ignore invalid lines.
        if line.len == 0:
            continue

        #Add the message to the unprocessed messages.
        unprocessed.add(
            newMessage(
                id,
                line
            )
        )

#Listen on a port.
proc listen*(port: int) {.async.} =
    #Start listening.
    server.setSockOpt(OptReuseAddr, true)
    server.bindAddr(Port(port))
    server.listen()

    #Accept new connections infinitely.
    while true:
        #Create a ServerClient around the socket.
        var client: ServerClient = newServerClient(
            clientCount,
            await server.accept()
        )

        #Add the new client to the clients.
        clients.add(client)
        #Handle the new client.
        asyncCheck handle(client)
        #Increment the client count.
        inc(clientCount)

#Sends a message to all clients.
proc broadcast*(msg: string) =
    for client in clients:
        asyncCheck client.send(msg)

#Reply to a message.
proc reply*(msg: Message, toSend: string) =
    for client in clients:
        if client.getID() == msg.getClient():
            asyncCheck client.send(toSend)
            break

#Returns an unprocessed message if one exists.
proc getMessage*(): Message {.raises: [].} =
    #If there are no messages, return an invalid message.
    if unprocessed.len == 0:
        return newMessage(-1, "")

    #The result if the first message.
    result = unprocessed[0]
    #Remove the first message from the unprocessed message queue.
    unprocessed.delete(0)
