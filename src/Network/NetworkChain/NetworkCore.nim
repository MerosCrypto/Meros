#Include the first file in the chain, NetworkImports.
include NetworkImports

#Broadcast a message.
proc broadcast*(
    network: Network,
    msg: Message
) {.forceCheck: [], async.} =
    try:
        await network.clients.broadcast(msg)
    except Exception as e:
        doAssert(false, "Clients.broadcast(Message) threw an Exception not naturally throwing any Exception: " & e.msg)

#Reply to a message.
proc reply*(
    network: Network,
    msg: Message,
    res: Message
) {.forceCheck: [
    IndexError
], async.} =
    try:
        await network.clients.reply(msg, res)
    except IndexError as e:
        raise e
    except Exception as e:
        doAssert(false, "Clients.reply(Message, Message) threw an Exception not naturally throwing any Exception: " & e.msg)

#Constructor.
proc newNetwork*(
    id: int,
    protocol: int,
    server: bool,
    port: int,
    allowRepeatConnections: bool,
    mainFunctions: GlobalFunctionBox
): Network {.forceCheck: [].} =
    #Create the Network.
    var network: Network = newNetworkObj(
        id,
        protocol,
        server,
        port,
        newNetworkLibFunctionBox(),
        mainFunctions
    )
    #Set the result to network.
    #We don't just use result so handle can access network.
    result = network

    #Provide functions for the Network Functions Box.
    result.networkFunctions.allowRepeatConnections = func (): bool {.forceCheck: [].} =
        allowRepeatConnections

    result.networkFunctions.getNetworkID = func (): int {.forceCheck: [].} =
        id
    result.networkFunctions.getProtocol = func (): int {.forceCheck: [].} =
        protocol
    result.networkFunctions.getPort = func (): int {.forceCheck: [].} =
        port

    result.networkFunctions.getClients = proc (): seq[Client] {.forceCheck: [].} =
        network.clients.clients

    result.networkFunctions.getTail = mainFunctions.merit.getTail
    result.networkFunctions.getBlockHashBefore = mainFunctions.merit.getBlockHashBefore
    result.networkFunctions.getBlockHashAfter = mainFunctions.merit.getBlockHashAfter

    result.networkFunctions.getBlock = mainFunctions.merit.getBlockByHash
    result.networkFunctions.getTransaction = mainFunctions.transactions.getTransaction

    result.networkFunctions.handle = proc (
        msg: Message
    ) {.forceCheck: [
        ClientError,
        Spam
    ], async.} =
        #Handle the message.
        case msg.content:
            of MessageType.Handshake:
                try:
                    await network.clients.reply(
                        msg,
                        newMessage(
                            MessageType.BlockchainTail,
                            mainFunctions.merit.getTail().toString()
                        )
                    )
                except IndexError:
                    raise newException(ClientError, "Couldn't respond to a Handshake sent as a keep-alive message.")
                except Exception as e:
                    doAssert(false, "Replying `Handshake` in response to a keep-alive `Handshake` threw an Exception despite catching all thrown Exceptions: " & e.msg)

                #Create an artificial BlockchainTail message.
                try:
                    await network.networkFunctions.handle(newMessage(MessageType.BlockchainTail, msg.message[5 ..< 37]))
                except ClientError as e:
                    raise e
                except Spam as e:
                    doAssert(false, "BlockchainTail message raised a Spam exception: " & e.msg)
                except Exception as e:
                    doAssert(false, "Handling a BlockchainTail threw an Exception despite catching all thrown Exceptions: " & e.msg)

            of MessageType.BlockchainTail:
                #Get the hash.
                var tail: Hash[256]
                try:
                    tail = msg.message[0 ..< 32].toHash(256)
                except ValueError as e:
                    doAssert(false, "Couldn't turn a 32-byte string into a 32-byte hash: " & e.msg)

                #Add the Block.
                try:
                    await mainFunctions.merit.addBlockByHash(tail, true)
                except ValueError as e:
                    raise newException(ClientError, "Client sent us a tail which failed to add due to a ValueError: " & e.msg)
                except DataMissing as e:
                    raise newException(ClientError, "Client sent us a tail which failed to fully sync: " & e.msg)
                except DataExists as e:
                    return
                except NotConnected:
                    return
                except Exception as e:
                    doAssert(false, "Adding a Block threw an Exception despite catching all thrown Exceptions: " & e.msg)

            of MessageType.Claim:
                var claim: Claim
                try:
                    claim = msg.message.parseClaim()
                except ValueError as e:
                    raise newException(ClientError, "Claim contained an invalid Signature: " & e.msg)

                try:
                    mainFunctions.transactions.addClaim(claim)
                except ValueError as e:
                    raise newException(ClientError, "Adding the Claim failed due to a ValueError: " & e.msg)
                except DataExists:
                    return

            of MessageType.Send:
                var send: Send
                try:
                    send = msg.message.parseSend(network.mainFunctions.consensus.getSendDifficulty())
                except ValueError as e:
                    raise newException(ClientError, "Send contained an invalid Signature: " & e.msg)
                except Spam as e:
                    raise e

                try:
                    mainFunctions.transactions.addSend(send)
                except ValueError as e:
                    raise newException(ClientError, "Adding the Send failed due to a ValueError: " & e.msg)
                except DataExists:
                    return

            of MessageType.Data:
                var data: Data
                try:
                    data = msg.message.parseData(network.mainFunctions.consensus.getDataDifficulty())
                except ValueError as e:
                    raise newException(ClientError, "Parsing the Data failed due to a ValueError: " & e.msg)
                except Spam as e:
                    raise e

                try:
                    mainFunctions.transactions.addData(data)
                except ValueError as e:
                    raise newException(ClientError, "Adding the Data failed due to a ValueError: " & e.msg)
                except DataExists:
                    return

            of MessageType.SignedVerification:
                var verif: SignedVerification
                try:
                    verif = msg.message.parseSignedVerification()
                except ValueError as e:
                    raise newException(ClientError, "SignedVerification didn't contain a valid signature: " & e.msg)

                try:
                    mainFunctions.consensus.addSignedVerification(verif)
                except ValueError as e:
                    raise newException(ClientError, "Adding the SignedVerification failed due to a ValueError: " & e.msg)
                except DataExists:
                    return

            of MessageType.SignedSendDifficulty:
                var sendDiff: SignedSendDifficulty
                try:
                    sendDiff = msg.message.parseSignedSendDifficulty()
                except ValueError as e:
                    raise newException(ClientError, "SignedSendDifficulty didn't contain a valid signature: " & e.msg)

                try:
                    mainFunctions.consensus.addSignedSendDifficulty(sendDiff)
                except ValueError as e:
                    raise newException(ClientError, "Adding the SignedSendDifficulty failed due to a ValueError: " & e.msg)
                except DataExists:
                    return

            of MessageType.SignedDataDifficulty:
                var dataDiff: SignedDataDifficulty
                try:
                    dataDiff = msg.message.parseSignedDataDifficulty()
                except ValueError as e:
                    raise newException(ClientError, "SignedDataDifficulty didn't contain a valid signature: " & e.msg)

                try:
                    mainFunctions.consensus.addSignedDataDifficulty(dataDiff)
                except ValueError as e:
                    raise newException(ClientError, "Adding the SignedDataDifficulty failed due to a ValueError: " & e.msg)
                except DataExists:
                    return

            of MessageType.SignedMeritRemoval:
                var mr: SignedMeritRemoval
                try:
                    mr = msg.message.parseSignedMeritRemoval()
                except ValueError as e:
                    raise newException(ClientError, "Parsing the SignedMeritRemoval failed due to a ValueError: " & e.msg)

                try:
                    await mainFunctions.consensus.addSignedMeritRemoval(mr)
                except ValueError as e:
                    raise newException(ClientError, "Adding the SignedMeritRemoval failed due to a ValueError: " & e.msg)
                except DataExists:
                    return
                except Exception as e:
                    doAssert(false, "Adding a SignedMeritRemoval threw an Exception despite catching all thrown Exceptions: " & e.msg)

            of MessageType.BlockHeader:
                var header: BlockHeader
                try:
                    header = msg.message.parseBlockHeader()
                except ValueError as e:
                    raise newException(ClientError, "Block didn't contain a valid hash: " & e.msg)

                try:
                    await mainFunctions.merit.addBlockByHeader(header, false)
                except ValueError as e:
                    raise newException(ClientError, "Adding the Block failed due to a ValueError: " & e.msg)
                except DataMissing:
                    return
                except DataExists:
                    return
                except NotConnected:
                    return
                except Exception as e:
                    doAssert(false, "Adding a Block threw an Exception despite catching all thrown Exceptions: " & e.msg)

            of MessageType.End:
                doAssert(false, "Trying to handle a Message of Type End despite explicitly refusing to receive messages of Type End.")

            else:
                raise newException(ClientError, "Client sent us a message which can only be sent while syncing when neither of us are syncing.")

#Listen on a port.
proc listen*(
    network: Network
) {.forceCheck: [], async.} =
    #Start listening.
    try:
        network.server = newAsyncSocket()
    except ValueError as e:
        doAssert(false, "Failed to create the Network's server socket due to a ValueError: " & e.msg)
    except IOSelectorsException as e:
        doAssert(false, "Failed to create the Network's server socket due to an IOSelectorsException: " & e.msg)
    except Exception as e:
        doAssert(false, "Failed to create the Network's server socket due to an Exception: " & e.msg)

    try:
        network.server.setSockOpt(OptReuseAddr, true)
        network.server.bindAddr(Port(network.port))
    except OSError as e:
        doAssert(false, "Failed to set the Network's server socket options and bind it due to an OSError: " & e.msg)
    except ValueError as e:
        doAssert(false, "Failed to bind the Network's server socket due to a ValueError: " & e.msg)

    #Start listening.
    try:
        network.server.listen()
    except OSError as e:
        doAssert(false, "Failed to start listening on the Network's server socket due to an OSError: " & e.msg)
    except Exception as e:
        doAssert(false, "Failed to start listening on the Network's server socket due to an Exception: " & e.msg)

    #Accept new connections infinitely.
    while not network.server.isClosed():
        #Accept a new client.
        #This is in a try/catch since ending the server while accepting a new Client will throw an Exception.
        try:
            var client: AsyncSocket = await network.server.accept()

            #Pass it to Clients.
            asyncCheck network.clients.add(
                true,
                network.port,
                client,
                network.networkFunctions
            )
        except Exception:
            continue

#Connect to a node.
proc connect*(
    network: Network,
    ip: string,
    port: int
) {.forceCheck: [
    ClientError
], async.} =
    #Create the socket.
    var socket: AsyncSocket
    try:
        socket = newAsyncSocket()
    except OSError as e:
        doAssert(false, "Couldn't create a client socket due to an OSError: " & e.msg)
    except ValueError as e:
        doAssert(false, "Couldn't create a client socket due to an ValueError: " & e.msg)
    except IOSelectorsException as e:
        doAssert(false, "Failed to create the Network's server socket due to an IOSelectorsException: " & e.msg)
    except Exception as e:
        doAssert(false, "Failed to create the Network's server socket due to an Exception: " & e.msg)

    #Connect.
    try:
        await socket.connect(ip, Port(port))
        #Pass it off to clients.
        asyncCheck network.clients.add(
            not network.server.isNil,
            network.port,
            socket,
            network.networkFunctions
        )
    except Exception as e:
        raise newException(ClientError, "Couldn't connect to a node: " & e.msg)

#Shutdown all Network operations.
proc shutdown*(
    network: Network
) {.forceCheck: [].} =
    try:
        #Stop the server.
        network.server.close()
    except Exception:
        discard

    #Shutdown the clients.
    network.clients.shutdown()
