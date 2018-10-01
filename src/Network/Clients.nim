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

    while not client.closed:
        #Receive the header.
        header = await client.recv(4)
        #Verify the length.
        if header.len != 4:
            #If the header length was specifically 0, meaning a dc'ed client...
            if header.len == 0:
                return
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
    for client in clients.clients:
        if not client.isClosed():
            asyncCheck client.send($msg)

#Reply to a message.
proc reply*(clients: Clients, msg: Message, toSend: string) {.raises: [Exception].} =
    var client: Client = clients.getClient(msg.client)
    if not client.isClosed():
        asyncCheck client.send(toSend)

#Disconnect a client.
proc disconnect*(clients: Clients, msg: Message) {.raises: [Exception].} =
    clients.disconnect(msg.client)
