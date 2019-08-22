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
        fcRaise e
    except Exception as e:
        doAssert(false, "Clients.reply(Message, Message) threw an Exception not naturally throwing any Exception: " & e.msg)

#Constructor.
proc newNetwork*(
    id: int,
    protocol: int,
    mainFunctions: GlobalFunctionBox
): Network {.forceCheck: [].} =
    #Create the Network.
    var network: Network = newNetworkObj(
        id,
        protocol,
        newClients(),
        newNetworkLibFunctionBox(),
        mainFunctions
    )
    #Set the result to network.
    #We don't just use result so handle can access network.
    result = network

    #Provide functions for the Network Functions Box.
    result.networkFunctions.getNetworkID = func (): int {.forceCheck: [].} =
        id

    result.networkFunctions.getProtocol = func (): int {.forceCheck: [].} =
        protocol

    result.networkFunctions.getHeight = mainFunctions.merit.getHeight

    result.networkFunctions.handle = proc (
        msg: Message
    ) {.forceCheck: [
        IndexError,
        SocketError,
        ClientError,
        InvalidMessageError
    ], async.} =
        try:
            if network.clients[msg.client].ourState == ClientState.Syncing:
                doAssert(false, "We are attempting to handle a message yet we're Syncing, which shouldn't cause this code to be called.")
        except IndexError as e:
            fcRaise e

        #Handle the message.
        case msg.content:
            #These messages should never make it to handle.
            of MessageType.Syncing:
                raise newException(InvalidMessageError, "Client sent us a `Syncing` which made its way to handle.")
            of MessageType.SyncingOver:
                raise newException(InvalidMessageError, "Client sent us a `SyncingOver` which made its way to handle.")
            of MessageType.SyncingAcknowledged:
                raise newException(InvalidMessageError, "Client sent us a `SyncingAcknowledged` when we aren't syncing.")
            of MessageType.DataMissing:
                raise newException(InvalidMessageError, "Client sent us a `DataMissing` when we aren't syncing.")
            of MessageType.BlockHash:
                raise newException(InvalidMessageError, "Client sent us a `BlockHash` when we aren't syncing.")
            of MessageType.BlockBody:
                raise newException(InvalidMessageError, "Client sent us a `BlockBody` when we aren't syncing.")
            of MessageType.Verification:
                raise newException(InvalidMessageError, "Client sent us a `Verification` when we aren't syncing.")
            of MessageType.MeritRemoval:
                raise newException(InvalidMessageError, "Client sent us a `MeritRemoval` when we aren't syncing.")

            of MessageType.Handshake:
                try:
                    await network.clients.reply(
                        msg,
                        newMessage(
                            MessageType.BlockHeight,
                            mainFunctions.merit.getHeight().toBinary().pad(INT_LEN)
                        )
                    )
                except IndexError:
                    raise newException(ClientError, "Couldn't respond to a Handshake sent as a keep-alive message.")
                except Exception as e:
                    doAssert(false, "Replying `Handshake` in response to a keep-alive `Handshake` threw an Exception despite catching all thrown Exceptions: " & e.msg)

            of MessageType.BlockHeight:
                try:
                    if network.clients[msg.client].theirState == ClientState.Syncing:
                        raise newException(InvalidMessageError, "Client sent us a BlockHeight when they are syncing.")
                except IndexError:
                    raise newException(ClientError, "Couldn't grab a Client who sent us a `BlockHeight`.")
                discard

            of MessageType.BlockHeaderRequest, MessageType.BlockBodyRequest:
                #Grab our chain height and parse the requested hash.
                var
                    height: int = mainFunctions.merit.getHeight()
                    req: Hash[384]
                    res: Block
                try:
                    req = msg.message.toHash(384)
                except ValueError as e:
                    raise newException(ClientError, "`BlockHeaderRequest`/`BlockBodyRequest` contained an invalid hash: " & e.msg)

                try:
                    if req.empty and (msg.content == MessageType.BlockHeaderRequest):
                        res = network.mainFunctions.merit.getBlockByNonce(height - 1)
                    else:
                        res = network.mainFunctions.merit.getBlockByHash(req)
                #If we don't have that block, send them DataMissing.
                except IndexError:
                    try:
                        await network.clients.reply(
                            msg,
                            newMessage(MessageType.DataMissing)
                        )
                        return
                    except IndexError as e:
                        fcRaise e
                    except SocketError as e:
                        fcRaise e
                    except ClientError as e:
                        fcRaise e
                    except Exception as e:
                        doAssert(false, "Sending `DataMissing` in response to a `BlockHeaderRequest`/`BlockBodyRequest` threw an Exception despite catching all thrown Exceptions: " & e.msg)

                #Since we have the Block, serialize the requested part.
                var serialized: string
                if msg.content == MessageType.BlockHeaderRequest:
                    serialized = res.header.serialize()
                elif msg.content == MessageType.BlockBodyRequest:
                    serialized = res.body.serialize()
                else:
                    doAssert(false, "Handling a message other than a `BlockHeaderRequest`/`BlockBodyRequest` in a branch for only those two messages.")

                #Send it.
                try:
                    await network.clients.reply(
                        msg,
                        newMessage(
                            if msg.content == MessageType.BlockHeaderRequest: MessageType.BlockHeader else: MessageType.BlockBody,
                            serialized
                        )
                    )
                except IndexError as e:
                    fcRaise e
                except SocketError as e:
                    fcRaise e
                except ClientError as e:
                    fcRaise e
                except Exception as e:
                    doAssert(false, "Sending a BlockHeader/BlockBody in response to a `BlockHeaderRequest`/`BlockBodyRequest` threw an Exception despite catching all thrown Exceptions: " & e.msg)

            of MessageType.ElementRequest:
                var
                    req: seq[string] = msg.message.deserialize(
                        BLS_PUBLIC_KEY_LEN,
                        INT_LEN
                    )
                    key: BLSPublicKey
                    nonce: int = req[1].fromBinary()
                    height: int
                try:
                    key = newBLSPublicKey(req[0])
                except BLSError as e:
                    raise newException(InvalidMessageError, "`ElementRequest` contained an invalid BLS Public Key: " & e.msg)

                height = mainFunctions.consensus.getHeight(key)
                if height <= nonce:
                    try:
                        await network.clients.reply(
                            msg,
                            newMessage(MessageType.DataMissing)
                        )
                        return
                    except IndexError as e:
                        fcRaise e
                    except SocketError as e:
                        fcRaise e
                    except ClientError as e:
                        fcRaise e
                    except Exception as e:
                        doAssert(false, "Sending `DataMissing` in response to a `ElementRequest` threw an Exception despite catching all thrown Exceptions: " & e.msg)

                try:
                    var
                        elem: Element = mainFunctions.consensus.getElement(key, nonce)
                        header: MessageType
                    case elem:
                        of Verification as _:
                            header = MessageType.Verification
                        #of SendDifficulty as _:
                        #    header = MessageType.SendDifficulty
                        #of DataDifficulty as _:
                        #    header = MessageType.DataDifficulty
                        #of GasPrice as _:
                        #    header = MessageType.GasPrice
                        of MeritRemoval as _:
                            header = MessageType.MeritRemoval
                        else:
                            doAssert(false, "Sending an unsupported Element in response to an ElementRequest.")

                    await network.clients.reply(
                        msg,
                        newMessage(
                            header,
                            elem.serialize()
                        )
                    )
                except IndexError as e:
                    fcRaise e
                except SocketError as e:
                    fcRaise e
                except ClientError as e:
                    fcRaise e
                except Exception as e:
                    doAssert(false, "Sending a Verification in response to a `ElementRequest` threw an Exception despite catching all thrown Exceptions: " & e.msg)

            of MessageType.TransactionRequest:
                #Declare the Transaction and a MessageType used to send it with.
                var
                    tx: Transaction
                    msgType: MessageType

                try:
                    #Try to get the Transaction.
                    tx = mainFunctions.transactions.getTransaction(msg.message.toHash(384))
                except ValueError as e:
                    raise newException(ClientError, "`TransactionRequest` contained an invalid hash: " & e.msg)
                except IndexError:
                    #If that failed, return DataMissing.
                    try:
                        await network.clients.reply(
                            msg,
                            newMessage(MessageType.DataMissing)
                        )
                        return
                    except IndexError as e:
                        fcRaise e
                    except SocketError as e:
                        fcRaise e
                    except ClientError as e:
                        fcRaise e
                    except Exception as e:
                        doAssert(false, "Sending `DataMissing` in response to a `TransactionRequest` threw an Exception despite catching all thrown Exceptions: " & e.msg)

                #Verify we didn't get a Mint, which should not be transmitted.
                if tx of Mint:
                    #Return DataMissing.
                    try:
                        await network.clients.reply(
                            msg,
                            newMessage(MessageType.DataMissing)
                        )
                        return
                    except IndexError as e:
                        fcRaise e
                    except SocketError as e:
                        fcRaise e
                    except ClientError as e:
                        fcRaise e
                    except Exception as e:
                        doAssert(false, "Sending `DataMissing` in response to a `TransactionRequest` threw an Exception despite catching all thrown Exceptions: " & e.msg)

                #Serialize the TX.
                var serialized: string = tx.serialize()
                #Set the message type.
                case tx:
                    of Mint as _:
                        discard
                    of Claim as _:
                        msgType = MessageType.Claim
                    of Send as _:
                        msgType = MessageType.Send
                    of Data as _:
                        msgType = MessageType.Data

                #Send the Transaction.
                try:
                    await network.clients.reply(
                        msg,
                        newMessage(
                            msgType,
                            serialized
                        )
                    )
                except IndexError as e:
                    fcRaise e
                except SocketError as e:
                    fcRaise e
                except ClientError as e:
                    fcRaise e
                except Exception as e:
                    doAssert(false, "Sending an Transaction in response to a `TransactionRequest` threw an Exception despite catching all thrown Exceptions: " & e.msg)

            of MessageType.GetBlockHash:
                #Grab our chain height and parse the requested nonce.
                var
                    height: int = mainFunctions.merit.getHeight()
                    req: int = msg.message.fromBinary()
                    res: Hash[384]

                try:
                    if req == 0:
                        res = network.mainFunctions.merit.getBlockByNonce(height - 1).hash
                    else:
                        res = network.mainFunctions.merit.getBlockByNonce(req).hash
                #If we don't have that block, send them DataMissing.
                except IndexError:
                    try:
                        await network.clients.reply(
                            msg,
                            newMessage(MessageType.DataMissing)
                        )
                        return
                    except IndexError as e:
                        fcRaise e
                    except SocketError as e:
                        fcRaise e
                    except ClientError as e:
                        fcRaise e
                    except Exception as e:
                        doAssert(false, "Sending `DataMissing` in response to a `GetBlockHash` threw an Exception despite catching all thrown Exceptions: " & e.msg)

                #Send it.
                try:
                    await network.clients.reply(
                        msg,
                        newMessage(
                            MessageType.BlockHash,
                            res.toString()
                        )
                    )
                except IndexError as e:
                    fcRaise e
                except SocketError as e:
                    fcRaise e
                except ClientError as e:
                    fcRaise e
                except Exception as e:
                    doAssert(false, "Sending a `BlockHash` in response to a `GetBlockHash` threw an Exception despite catching all thrown Exceptions: " & e.msg)

            of MessageType.Claim:
                var claim: Claim
                try:
                    claim = msg.message.parseClaim()
                except ValueError as e:
                    raise newException(InvalidMessageError, "Claim contained an invalid Signature: " & e.msg)
                except BLSError as e:
                    raise newException(InvalidMessageError, "Claim contained an invalid BLS Public Key: " & e.msg)
                except EdPublicKeyError as e:
                    raise newException(InvalidMessageError, "Claim contained an invalid ED25519 Public Key: " & e.msg)

                try:
                    mainFunctions.transactions.addClaim(claim)
                except ValueError as e:
                    raise newException(InvalidMessageError, "Adding the Claim failed due to a ValueError: " & e.msg)
                except DataExists:
                    return

            of MessageType.Send:
                var send: Send
                try:
                    send = msg.message.parseSend()
                except ValueError as e:
                    raise newException(InvalidMessageError, "Send contained an invalid Signature: " & e.msg)
                except EdPublicKeyError as e:
                    raise newException(InvalidMessageError, "Send contained an invalid ED25519 Public Key: " & e.msg)

                try:
                    mainFunctions.transactions.addSend(send)
                except ValueError as e:
                    raise newException(InvalidMessageError, "Adding the Send failed due to a ValueError: " & e.msg)
                except DataExists:
                    return

            of MessageType.Data:
                var data: Data
                try:
                    data = msg.message.parseData()
                except ValueError as e:
                    raise newException(InvalidMessageError, "Parsing the Data failed due to a ValueError: " & e.msg)

                try:
                    mainFunctions.transactions.addData(data)
                except ValueError as e:
                    raise newException(InvalidMessageError, "Adding the Data failed due to a ValueError: " & e.msg)
                except DataExists:
                    return

            of MessageType.SignedVerification:
                var verif: SignedVerification
                try:
                    verif = msg.message.parseSignedVerification()
                except ValueError as e:
                    raise newException(InvalidMessageError, "SignedVerification didn't contain a valid hash: " & e.msg)
                except BLSError as e:
                    raise newException(InvalidMessageError, "SignedVerification contained an invalid BLS Public Key: " & e.msg)

                try:
                    mainFunctions.consensus.addSignedVerification(verif)
                except ValueError as e:
                    raise newException(InvalidMessageError, "Adding the SignedVerification failed due to a ValueError: " & e.msg)
                except GapError:
                    return
                except DataExists:
                    return

            of MessageType.SignedMeritRemoval:
                var mr: SignedMeritRemoval
                try:
                    mr = msg.message.parseSignedMeritRemoval()
                except ValueError as e:
                    raise newException(InvalidMessageError, "Parsing the SignedVerification failed due to a ValueError: " & e.msg)
                except BLSError as e:
                    raise newException(InvalidMessageError, "Parsing the SignedVerification failed due to a BLSError: " & e.msg)

                try:
                    mainFunctions.consensus.addSignedMeritRemoval(mr)
                except ValueError as e:
                    raise newException(InvalidMessageError, "Adding the SignedMeritRemoval failed due to a ValueError: " & e.msg)

            of MessageType.BlockHeader:
                var header: BlockHeader
                try:
                    header = msg.message.parseBlockHeader()
                except ValueError as e:
                    raise newException(InvalidMessageError, "Block didn't contain a valid hash: " & e.msg)
                except BLSError as e:
                    raise newException(InvalidMessageError, "Block contained an invalid BLS Public Key: " & e.msg)

                try:
                    await mainFunctions.merit.addBlockByHeader(header)
                except ValueError as e:
                    echo "Failed to add the Block due to a ValueError: " & e.msg
                    raise newException(InvalidMessageError, "Adding the Block failed due to a ValueError: " & e.msg)
                except IndexError as e:
                    echo "Failed to add the Block due to a IndexError: " & e.msg
                    raise newException(InvalidMessageError, "Adding the Block failed due to a IndexError: " & e.msg)
                except GapError as e:
                    echo "Failed to add the Block due to a GapError: " & e.msg
                    return
                except DataExists:
                    return
                except Exception as e:
                    doAssert(false, "Adding a Block threw an Exception despite catching all thrown Exceptions: " & e.msg)

            of MessageType.End:
                doAssert(false, "Trying to handle a Message of Type End despite explicitly refusing to receive messages of Type End.")

    result.networkFunctions.handleBlock = mainFunctions.merit.addBlock

#Listen on a port.
proc listen*(
    network: Network,
    config: Config
) {.forceCheck: [], async.} =
    #Start listening.
    try:
        network.server = newAsyncSocket()
    except FinalAttributeError as e:
        doAssert(false, "Server is already listening: " & e.msg)
    except ValueError as e:
        doAssert(false, "Failed to create the Network's server socket due to a ValueError: " & e.msg)
    except IOSelectorsException as e:
        doAssert(false, "Failed to create the Network's server socket due to an IOSelectorsException: " & e.msg)
    except Exception as e:
        doAssert(false, "Failed to create the Network's server socket due to an Exception: " & e.msg)

    try:
        network.server.setSockOpt(OptReuseAddr, true)
        network.server.bindAddr(Port(config.tcpPort))
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
        var client: tuple[address: string, client: AsyncSocket]
        try:
            client = await network.server.acceptAddr()

            #Pass it to Clients.
            asyncCheck network.clients.add(
                client.address,
                0,
                true,
                client.client,
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
            ip,
            port,
            not network.server.isNil,
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
