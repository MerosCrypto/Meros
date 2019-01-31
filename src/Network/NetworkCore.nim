#Include the first file in the chain, NetworkImports.
include NetworkImports

#Broadcast a message.
proc broadcast*(network: Network, msg: Message) {.async.} =
    await network.clients.broadcast(msg)

#Reply to a message.
proc reply*(network: Network, msg: Message, res: Message) {.async.} =
    await network.clients.reply(msg, res)

#Constructor.
proc newNetwork*(
    id: uint,
    protocol: uint,
    mainFunctions: MainFunctionBox
): Network {.raises: [SocketError].} =
    #Create the server socket.
    var server: AsyncSocket
    try:
        server = newAsyncSocket()
    except:
        raise newException(SocketError, "Couldn't create a socket for the server.")

    #Create the Network.
    var network: Network = newNetworkObj(
        id,
        protocol,
        newClients(),
        server,
        newNetworkLibFunctionBox(),
        mainFunctions
    )
    #Set the result to network.
    #We don't just use result so handle can access network.
    result = network

    #Provide functions for the Network Functions Box.
    result.networkFunctions.getNetworkID = proc (): uint {.raises: [].} =
        id

    result.networkFunctions.getProtocol = proc (): uint {.raises: [].} =
        protocol

    result.networkFunctions.getHeight = proc (): uint {.raises: [].} =
        mainFunctions.merit.getHeight()

    result.networkFunctions.handle = proc (msg: Message): Future[bool] {.async.} =
        #Set the result to true.
        result = true

        #Try to handle the message.
        try:
            case msg.content:
                of MessageType.Handshake:
                    #Return false since we should've already handshaked.
                    return false

                #These three messages should never make it to handle.
                of MessageType.Syncing:
                    echo "We are attempting to handle a message which should've never made it to handle."
                of MessageType.SyncingOver:
                    echo "We are attempting to handle a message which should've never made it to handle."
                of MessageType.DataMissing:
                    echo "We are attempting to handle a message which should've never made it to handle."

                #This message should only be received if we're syncing and handled by syncing.
                of MessageType.Verification:
                    echo "We are attempting to handle a Verification which shouldn't happen."

                of MessageType.BlockRequest:
                    #Grab our chain height and parse the requested nonce.
                    var
                        height: uint = mainFunctions.merit.getHeight()
                        req: uint = uint(msg.message.fromBinary())

                    #If we don't have that block, send them DataMissing.
                    if height <= req:
                        await network.clients.reply(
                            msg,
                            newMessage(MessageType.DataMissing)
                        )
                    #Since we have it, grab it, serialize it, and send it.
                    else:
                        await network.clients.reply(
                            msg,
                            newMessage(
                                MessageType.Block,
                                mainFunctions.merit.getBlock(req).serialize()
                            )
                        )

                of MessageType.VerificationRequest:
                    var
                        req: seq[string] = msg.message.deserialize(2)
                        key: string = req[0].pad(48)
                        nonce: uint = uint(req[1].fromBinary())
                        height: uint = mainFunctions.verifications.getVerifierHeight(key)

                    if height <= nonce:
                        await network.clients.reply(
                            msg,
                            newMessage(MessageType.DataMissing)
                        )
                    else:
                        await network.clients.reply(
                            msg,
                            newMessage(
                                MessageType.Verification,
                                mainFunctions.verifications.getVerification(key, nonce).serialize()
                            )
                        )

                of MessageType.EntryRequest:
                    #Declare the Entry and a MessageType used to send it with.
                    var
                        entry: Entry
                        msgType: MessageType

                    try:
                        #Try to get the Entry.
                        entry = mainFunctions.lattice.getEntryByHash(msg.message)
                    except:
                        #If that failed, return DataMissing.
                        await network.clients.reply(
                            msg,
                            newMessage(MessageType.DataMissing)
                        )

                    #Verify we didn't get a Mint, which should not be transmitted.
                    if entry.descendant == EntryType.Mint:
                        #Return DataMissing.
                        await network.clients.reply(
                            msg,
                            newMessage(MessageType.DataMissing)
                        )

                    #If we did get an Entry, that wasn't a Mint, set the MessageType.
                    case entry.descendant:
                        of EntryType.Mint:
                            discard
                        of EntryType.Claim:
                            msgType = MessageType.Claim
                        of EntryType.Send:
                            msgType = MessageType.Send
                        of EntryType.Receive:
                            msgType = MessageType.Receive
                        of EntryType.Data:
                            msgType = MessageType.Data

                    #Send the Entry.
                    await network.clients.reply(
                        msg,
                        newMessage(
                            msgType,
                            entry.serialize()
                        )
                    )

                of MessageType.Claim:
                    if mainFunctions.lattice.addClaim(msg.message.parseClaim()):
                        await network.clients.broadcast(msg)

                of MessageType.Send:
                    if mainFunctions.lattice.addSend(msg.message.parseSend()):
                        await network.clients.broadcast(msg)

                of MessageType.Receive:
                    if mainFunctions.lattice.addReceive(msg.message.parseReceive()):
                        await network.clients.broadcast(msg)

                of MessageType.Data:
                    if mainFunctions.lattice.addData(msg.message.parseData()):
                        await network.clients.broadcast(msg)

                of MessageType.MemoryVerification:
                    if mainFunctions.verifications.addMemoryVerification(
                        msg.message.parseMemoryVerification()
                    ):
                        await network.clients.broadcast(msg)

                of MessageType.Block:
                    if await mainFunctions.merit.addBlock(msg.message.parseBlock()):
                        await network.clients.broadcast(msg)
        except:
            #If we encountered an error handling the message, return false.
            return false

#Listen on a port.
proc listen*(network: Network, port: uint) {.async.} =
    #Start listening.
    network.server.setSockOpt(OptReuseAddr, true)
    network.server.bindAddr(Port(port))
    network.server.listen()

    #Accept new connections infinitely.
    while not network.server.isClosed():
        #This is in a try/catch since ending the server while accepting a new Client will throw an Exception.
        try:
            #Accept a new client.
            var client: tuple[address: string, client: AsyncSocket] = await network.server.acceptAddr()
            #Pass it to Clients.
            asyncCheck network.clients.add(
                client.address,
                port,
                client.client,
                network.networkFunctions
            )
        except:
            continue

#Connect to a Client.
proc connect*(network: Network, ip: string, port: uint) {.async.} =
    #Create the socket.
    var socket: AsyncSocket = newAsyncSocket()
    #Connect.
    await socket.connect(ip, Port(port))
    #Pass it off to clients.
    asyncCheck network.clients.add(
        ip,
        port,
        socket,
        network.networkFunctions
    )

#Shutdown all Network operations.
proc shutdown*(network: Network) {.raises: [SocketError].} =
    try:
        #Stop the server.
        network.server.close()
    except:
        raise newException(SocketError, "Couldn't close the Network's server socket.")
    #Shutdown the clients.
    network.clients.shutdown()
