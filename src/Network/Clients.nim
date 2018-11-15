#Errors lib.
import ../lib/Errors

#Util lib.
import ../lib/Util

#Hash lib.
import ../lib/Hash

#Block libs.
import ../Database/Merit/Verifications
import ../Database/Merit/Block

#Lattice libs.
import ../Database/Lattice/Lattice

#Parse libs.
import Serialize/Merit/ParseBlock
import Serialize/Lattice/ParseClaim
import Serialize/Lattice/ParseSend
import Serialize/Lattice/ParseReceive
import Serialize/Lattice/ParseData

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

#Receive a header and message from a socket.
proc recv(socket: AsyncSocket): Future[tuple[header: string, msg: string]] {.async.} =
    var
        header: string
        size: int
        msg: string

    #Receive the header.
    header = await socket.recv(4)
    #Verify the length.
    if header.len != 4:
        #If the header length is 0 because the client disconnected...
        if header.len == 0:
            #Close the client.
            socket.close()
            #Stop handling the Client.
            return
        #Continue so we can get a valid header.
        raise newException(SocketError, "Didn't get a full header.")

    #Define the size.
    size = ord(header[3])
    #While the size is 255 bytes (signifying it's even bigger than that)...
    while ord(header[header.len - 1]) == 255:
        #Get a new byte.
        header &= await socket.recv(1)
        #Add it to the size.
        size += ord(header[header.len - 1])
    #Get the actual message.
    msg = await socket.recv(size)
    #Verify the length.
    if msg.len != size:
        raise newException(SocketError, "Didn't get a full message.")

    #Return a tuple of the header and the message.
    return (header, msg)

#Sync all data referenced by a Block using the socket.
proc sync*(newBlock: Block, network: Network, socket: AsyncSocket): Future[bool] {.async.} =
    result = true

    #Make sure we have all the Entries verified in it.
    var entries: seq[string] = @[]
    for verif in newBlock.verifications.verifications:
        try:
            discard network.nodeEvents.get(
                proc (hash: string): Entry,
                "lattice.getEntry"
            )(verif.hash.toString())
        except:
            if getCurrentExceptionMsg() == "Lattice does not have a Entry for that hash.":
                entries.add(verif.hash.toString())

    #Send syncing.
    await socket.send(
        char(network.id) &
        char(network.protocol) &
        char(MessageType.Syncing) &
        char(0)
    )

    #This is in a try block so we always send SyncingOver.
    try:
        #Ask for missing Entries.
        for entry in entries:
            #Send the Request.
            await socket.send(
                char(network.id) &
                char(network.protocol) &
                char(MessageType.EntryRequest) &
                !entry
            )

            #Get the response.
            var res: tuple[header: string, msg: string] = await socket.recv()
            #Add it.
            case MessageType(res.header[2]):
                of MessageType.Claim:
                    var claim: Claim = res.msg.parseClaim()
                    if not network.nodeEvents.get(
                        proc (claim: Claim): bool,
                        "lattice.claim"
                    )(claim):
                        return false

                of MessageType.Send:
                    var send: Send = res.msg.parseSend()
                    if not network.nodeEvents.get(
                        proc (send: Send): bool,
                        "lattice.send"
                    )(send):
                        return false

                of MessageType.Receive:
                    var recv: Receive = res.msg.parseReceive()
                    if not network.nodeEvents.get(
                        proc (recv: Receive): bool,
                        "lattice.receive"
                    )(recv):
                        return false

                of MessageType.Data:
                    var data: Data = res.msg.parseData()
                    if not network.nodeEvents.get(
                        proc (data: Data): bool,
                        "lattice.data"
                    )(data):
                        return false

                else:
                    return false
    except:
        result = false

    #Send SyncingOver.
    await socket.send(
        char(network.id) &
        char(network.protocol) &
        char(MessageType.SyncingOver) &
        char(0)
    )

#Handshake.
proc handshake(
    network: Network,
    socket: AsyncSocket
): Future[int] {.async.} =
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
    var handshake: tuple[header: string, msg: string] = await socket.recv()

    #Verify their Header.
    #Network ID.
    if uint(handshake.header[0]) != network.id:
        return 0
    #Protocol version.
    if uint(handshake.header[1]) != network.protocol:
        return 0
    #Message Type.
    if int(handshake.header[2]) != ord(MessageType.Handshake):
        return 0
    #Message length.
    if int(handshake.header[3]) > 4:
        return 0
    #Get their Blockchain height.
    theirHeight = uint(
        handshake.msg.fromBinary()
    )

    #If the result is 1, they need more info but we don't.
    #If the result is 2, both sides are good.
    result = 2
    if theirHeight < ourHeight:
        result = 1

    #If we have less Blocks, get what we need.
    if ourHeight < theirHeight:
        #Ask for each Block.
        for height in ourHeight ..< theirHeight:
            #Send the Request.
            await socket.send(
                char(network.id) &
                char(network.protocol) &
                char(MessageType.BlockRequest) &
                !height.toBinary()
            )

            #Parse it.
            var newBlock: Block

            try:
                newBlock = (await socket.recv()).msg.parseBlock()
            except:
                return 0

            #Get all the Entries it verifies.
            if not await newBlock.sync(network, socket):
                return 0

            #Add the block.
            if not await network.nodeEvents.get(
                proc (newBlock: Block): Future[bool],
                "merit.block"
            )(newBlock):
                return

        #Handshake over.
        await socket.send(
            char(network.id) &
            char(network.protocol) &
            char(MessageType.HandshakeOver) &
            !ourHeight.toBinary()
        )

#Handles a client.
proc handle(client: Client, eventEmitter: EventEmitter) {.async.} =
    var
        #Client ID.
        id: uint = client.id
        #Message loop variable.
        msg: tuple[header: string, msg: string]

    #While the client is still connected...
    while not client.isClosed():
        try:
            msg = await client.recv()
        except:
            continue

        case MessageType(msg.header[2]):
            of MessageType.Syncing:
                client.syncing = true
                continue

            of MessageType.SyncingOver:
                client.syncing = false
                continue

            of MessageType.HandshakeOver:
                client.shaking = false
                continue

            else:
                discard

        #Emit the new Message. If that returns false...
        if not (
            await eventEmitter.get(
                proc (msg: Message): Future[bool],
                "message"
            )(
                newMessage(
                    id,
                    uint(msg.header[0]),
                    uint(msg.header[1]),
                    MessageType(msg.header[2]),
                    uint(msg.msg.len),
                    msg.header,
                    msg.msg
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
    var handshakeCode: int = await network.handshake(socket)
    if handshakeCode == 0:
        return

    #Create the client.
    var client: Client = newClient(
        network.clients.total,
        socket
    )

    #If the handshake said both parties are equally synced...
    if handshakeCode == 2:
        client.shaking = false

    #Add it to the seq.
    network.clients.clients.add(client)
    #Increment the total so the next ID doesn't overlap.
    inc(network.clients.total)

    #Handle it.
    try:
        await client.handle(network.subEvents)
    except:
        #Due to async, the Exception we had here wasn't being handled.
        #Because it wasn't being handled, the Node crashed.
        #The Node shouldn't crash when a random Node disconnects.

        #Delete this client from Clients.
        network.clients.disconnect(client.id)

#Sends a message to all clients.
proc broadcast*(
    clients: Clients,
    msg: Message
) {.raises: [AsyncError].} =
    #Seq of the clients to disconnect.
    var toDisconnect: seq[uint] = @[]

    #Iterate over each client.
    for client in clients.clients:
        #Skip the Client who sent us this.
        if client.id == msg.client:
            continue

        #Skip Clients who are shaking/syncing.
        if client.shaking or client.syncing:
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
) {.raises: [AsyncError].} =
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
) {.raises: [].} =
    clients.disconnect(msg.client)
