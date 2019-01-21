#Errors lib.
import ../lib/Errors

#Util lib.
import ../lib/Util

#Hash lib.
import ../lib/Hash

#BLS lib.
import ../lib/BLS

#Block libs.
import ../Database/Verifications/Verifications
import ../Database/Merit/Block

#Lattice libs.
import ../Database/Lattice/Lattice

#Parse libs.
import Serialize/Verifications/ParseVerification
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
import mc_events

#Networking standard libs.
import asyncnet, asyncdispatch

#Seq utils standard lib.
import sequtils

#Tables standard lib.
import tables

import strutils

#Receive a header and message from a socket.
proc recv*(socket: AsyncSocket, handshake: bool = false): Future[tuple[header: string, msg: string]] {.async.} =
    var
        headerLen: int = 2
        header: string
        size: int
        msg: string

    if handshake:
        headerLen = 4

    #Receive the header.
    header = await socket.recv(headerLen)
    #Verify the length.
    if header.len != headerLen:
        #If the header length is 0 because the client disconnected...
        if header.len == 0:
            #Close the client.
            socket.close()
            #Stop handling the Client.
            return
        #Continue so we can get a valid header.
        raise newException(SocketError, "Didn't get a full header.")

    #Define the size.
    size = ord(header[headerLen - 1])
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

    #Tuple to define missing data.
    type Gap = tuple[key: string, start: uint, last: uint]

    var
        #Variable for gaps.
        gaps: seq[Gap] = @[]
        #Define a table to store the hashes in.
        hashes: Table[string, seq[string]] = initTable[string, seq[string]]()
        #Table to store the Verifications in.
        verifications: Table[string, seq[Verification]] = initTable[string, seq[Verification]]()
        #List of verified Entries.
        entries: seq[string] = @[]

    #Make sure we have all the Verifications in it.
    for verifier in newBlock.verifications:
        #Add a seq for them in each table.
        hashes[verifier.key] = network.nodeEvents.get(
            proc (key: string, nonce: uint): seq[string],
            "verifications.getPendingHashes"
        )(verifier.key, verifier.nonce)

        verifications[verifier.key] = @[]

        #Get the Verifier's height.
        var verifHeight: uint = network.nodeEvents.get(
            proc (key: string): uint,
            "verifications.getVerifierHeight"
        )(verifier.key)

        #If we're missing Verifications...
        if verifHeight <= verifier.nonce:
            #Add the gap.
            gaps.add((
                verifier.key,
                verifHeight,
                verifier.nonce
            ))

    #If there are no gaps, return.
    if gaps.len == 0:
        return

    #Try block is here so if anything fails, we still send Stop Syncing.
    try:
        #Send syncing.
        await socket.send(
            char(MessageType.Syncing) &
            char(0)
        )

        #Ask for missing Verifications.
        for gap in gaps:
            #Send the Requests.
            for nonce in gap.start .. gap.last:
                await socket.send(
                    char(MessageType.VerificationRequest) &
                    !(
                        !gap.key &
                        !nonce.toBinary()
                    )
                )

                #Get the response.
                var res: tuple[header: string, msg: string] = await socket.recv()
                #Make sure it's a Verification.
                if MessageType(res.header[0]) != MessageType.Verification:
                    return false
                #Parse it.
                var verif: Verification = res.msg.parseVerification()
                #Verify it's from the correct person and has the correct nonce.
                if verif.verifier.toString() != gap.key:
                    return false
                if verif.nonce != nonce:
                    return false
                #Add it.
                verifications[gap.key].add(verif)
                hashes[gap.key].add(verif.hash.toString())
                entries.add(verif.hash.toString())

        #Check the Block's aggregate.
        #Aggregate Infos for each Verifier.
        var agInfos: seq[ptr BLSAggregationInfo] = @[]
        #Iterate over every Verifier.
        for index in newBlock.verifications:
            #Aggregate Infos for this verifier.
            var verifierAgInfos: seq[ptr BLSAggregationInfo] = @[]
            #Iterate over this verifier's hashes.
            for hash in hashes[index.key]:
                #Create AggregationInfos.
                verifierAgInfos.add(cast[ptr BLSAggregationInfo](alloc0(sizeof(BLSAggregationInfo))))
                verifierAgInfos[^1][] = newBLSAggregationInfo(newBLSPublicKey(index.key), hash)
            #Create the aggregate AggregateInfo for this Verifier.
            agInfos.add(cast[ptr BLSAggregationInfo](alloc0(sizeof(BLSAggregationInfo))))
            agInfos[^1][] = verifierAgInfos.aggregate()

        #Add the aggregate info to the Block's signature.
        newBlock.header.verifications.setAggregationInfo(agInfos.aggregate())
        #Verify the signature.
        if not newBlock.header.verifications.verify():
            return false

        #Download the Entries.
        #Dedeuplicate the list.
        entries = entries.deduplicate()
        #Iterate over each entry.
        for entry in entries:
            #Send the Request.
            await socket.send(
                char(MessageType.EntryRequest) &
                !entry
            )

            #Get the response.
            var res: tuple[header: string, msg: string] = await socket.recv()
            #Add it.
            case MessageType(res.header[0]):
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

        #Since we now have every Entry, add the Verifications.
        for index in newBlock.verifications:
            for verif in verifications[index.key]:
                #If we failed to add this (shows up as an Exception), due to a MeritRemoval, the Block won't be added.
                #That said, the aggregate proves these are valid Verifications.
                network.nodeEvents.get(
                    proc (verif: Verification),
                    "verifications.verification"
                )(verif)

    except:
        raise

    finally:
        #Send SyncingOver.
        await socket.send(
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
    var handshake: tuple[header: string, msg: string] = await socket.recv(true)

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
        for nonce in ourHeight ..< theirHeight:
            #Send the Request.
            await socket.send(
                char(MessageType.BlockRequest) &
                !nonce.toBinary()
            )

            #Parse it.
            var newBlock: Block
            try:
                newBlock = (await socket.recv()).msg.parseBlock()
            except:
                return 0

            #Get all the verifications it references and the entries those verify.
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

        case MessageType(msg.header[0]):
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
                    MessageType(msg.header[0]),
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
    ip: string,
    port: uint,
    socket: AsyncSocket
) {.async.} =
    #Make sure we aren't already connected to them.
    for client in network.clients.clients:
        if (
            (client.ip == ip) and
            (client.port == port)
        ):
            return

    #Handshake with the Socket.
    var handshakeCode: int
    try:
        handshakeCode = await network.handshake(socket)
    except:
        handshakeCode = 0
    if handshakeCode == 0:
        return

    #Create the client.
    var client: Client = newClient(
        ip,
        port,
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
