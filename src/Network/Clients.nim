#Errors lib.
import ../lib/Errors

#Util lib.
import ../lib/Util

#Block lib.
import ../Database/Merit/Block

#Send libs.
import ../Database/Lattice/Send
import Serialize/Lattice/ParseSend

#Receive libs.
import ../Database/Lattice/Receive
import Serialize/Lattice/ParseReceive

#Message/Client/Clients/Network objects.
import objects/ClientObj
import objects/ClientsObj
import objects/MessageObj
import objects/NetworkObj

#Serialize libs.
import Serialize/SerializeCommon
import Serialize/Merit/SerializeBlock

#Events lib.
import ec_events

#Networking standard libs.
import asyncnet, asyncdispatch

#Handshake.
proc handshake(
    network: Network,
    socket: AsyncSocket
) {.async.} =
    #Get the Blockchain height.
    var
        #Our Blockchain Height.
        ourHeight: uint
        #Their Blockchain Height.
        theirHeight: uint
    try:
        ourHeight = network.nodeEvents.get(
            proc (): uint,
            "merit.getHeight"
        )()
    except:
        raise newException(EventError, "Couldn't get and call merit.getHeight.")

    #Handshake.
    await socket.send(
        char(network.id) &
        char(network.protocol) &
        char(MessageType.Handshake) &
        !ourHeight.toBinary()
    )

    #Get their Handshake back.
    var header: string = await socket.recv(4)
    #Verify their Header.
    #Network ID.
    if uint(header[0]) != network.id:
        return
    #Protocol version.
    if uint(header[1]) != network.protocol:
        return
    #Message Type.
    if int(header[2]) != ord(MessageType.Handshake):
        return
    #Message length.
    if uint(header[3]) == 255:
        return
    #Get their Blockchain height.
    theirHeight = uint(
        (await socket.recv(
            int(header[3])
        )).fromBinary()
    )

    #If we have more Blocks, send them what we have.
    if ourHeight > theirHeight:
        #Define a proc to send the Block.
        proc sendBlock(syncBlock: Block, delay: int) {.async.} =
            #Sleep for the delay.
            await sleepAsync(delay)

            #Send it.
            await socket.send(
                char(network.id) &
                char(network.protocol) &
                char(MessageType.Block) &
                !syncBlock.serialize()
            )

        #Iterate over each block.
        for height in theirHeight ..< ourHeight:
            asyncCheck sendBlock(
                network.nodeEvents.get(
                    proc (nonce: uint): Block,
                    "merit.getBlock"
                )(height),
                10000 * int(height - theirHeight)
            )

#Handles a client.
proc handle(client: Client, eventEmitter: EventEmitter) {.async.} =
    var
        #Get the client ID.
        id: uint = client.id
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
        #Get the actual message.
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
                    uint(ord(header[0])),
                    uint(ord(header[1])),
                    MessageType(header[2]),
                    uint(size),
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
proc add*(
    network: Network,
    socket: AsyncSocket
) {.async.} =
    #Handshake with the Socket.
    await network.handshake(socket)

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
    try:
        await client.handle(network.subEvents)
    except:
        raise newException(AsyncError, "Couldn't handle a Client.")

#Sends a message to all clients.
proc broadcast*(
    clients: Clients,
    msg: Message
) {.raises: [AsyncError, SocketError].} =
    #Seq of the clients to disconnect.
    var toDisconnect: seq[uint] = @[]

    #Iterate over each client.
    for client in clients.clients:
        #Skip the Client who sent us this.
        if client.id == msg.client:
            continue

        #Make sure the client is open.
        if not client.isClosed():
            try:
                asyncCheck client.send($msg)
            except:
                raise newException(AsyncError, "Couldn't broacast to a Client.")
        #If it isn't, mark the client for disconnection.
        else:
            toDisconnect.add(client.id)

    #Disconnect the clients marked for disconnection.
    for client in toDisconnect:
        clients.disconnect(client)

#Reply to a message.
proc reply*(
    clients: Clients,
    msg: Message,
    toSend: string
) {.raises: [AsyncError, SocketError].} =
    #Get the client.
    var client: Client = clients.getClient(msg.client)
    #Make sure the client is open.
    if not client.isClosed():
        try:
            asyncCheck client.send(toSend)
        except:
            raise newException(AsyncError, "Couldn't reply to a Client.")
    #If it isn't, disconnect the client.
    else:
        clients.disconnect(client.id)

#Disconnect a client based off the message it sent.
proc disconnect*(
    clients: Clients,
    msg: Message
) {.raises: [SocketError].} =
    clients.disconnect(msg.client)
