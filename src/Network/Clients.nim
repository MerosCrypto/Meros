#Send libs.
import ../Database/Lattice/Send
import Serialize/ParseSend

#Receive libs.
import ../Database/Lattice/Receive
import Serialize/ParseReceive

#Message/Client/Clients/Network objects.
import objects/ClientObj
import objects/ClientsObj
import objects/MessageObj
import objects/NetworkObj

#Events lib.
import ec_events

#Networking standard libs.
import asyncnet, asyncdispatch

#Handles a client.
proc handle(client: Client, eventEmitter: EventEmitter) {.async.} =
    var
        #Get the client ID.
        id: int = client.id
        #Define the loop vars outside of the loop.
        header: string
        size: int
        line: string

    #While the client is still connected...
    while not client.isClosed():
        #Receive the header.
        header = await client.recv(4)
        #Verify the length.
        if header.len != 4:
            #If the header length is 0 because the client disconnected...
            if header.len == 0:
                #Close the client.
                client.close()
                #Stop handling the Client.
                return
            #Continue so we can get a valid header.
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
            await eventEmitter.get(
                proc (msg: Message): Future[bool],
                "message"
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
            client.close()
            #Break out of the loop.
            break

#Function which adds a Client from a socket.
proc add*(network: Network, socket: AsyncSocket) {.raises: [ValueError, Exception].} =
    #Create the client.
    var client = newClient(
        network.clients.total,
        socket
    )
    #Add it to the seq.
    network.clients.clients.add(client)
    #Increment the total so the next ID doesn't overlap.
    inc(network.clients.total)
    #Handle it.
    asyncCheck client.handle(network.subEvents)

#Sends a message to all clients.
proc broadcast*(clients: Clients, msg: Message) {.raises: [Exception].} =
    #Seq of the clients to disconnect.
    var toDisconnect: seq[int] = @[]

    #Iterate over each client.
    for client in clients.clients:
        #Make sure the client is open.
        if not client.isClosed():
            asyncCheck client.send($msg)
        #If it isn't, mark the client for disconnection.
        else:
            toDisconnect.add(client.id)

    #Disconnect the clients marked for disconnection.
    for client in toDisconnect:
        clients.disconnect(client)


#Reply to a message.
proc reply*(clients: Clients, msg: Message, toSend: string) {.raises: [Exception].} =
    #Get the client.
    var client: Client = clients.getClient(msg.client)
    #Make sure the client is open.
    if not client.isClosed():
        asyncCheck client.send(toSend)
    #If it isn't, disconnect the client.
    else:
        clients.disconnect(client.id)

#Disconnect a client based off the message it sent.
proc disconnect*(clients: Clients, msg: Message) {.raises: [Exception].} =
    clients.disconnect(msg.client)
