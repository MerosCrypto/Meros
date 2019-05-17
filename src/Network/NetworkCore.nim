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
            of MessageType.Handshake:
                raise newException(InvalidMessageError, "Client tried handshaking despite having already connected.")

            #These five messages should never make it to handle.
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
            of MessageType.Verification:
                raise newException(InvalidMessageError, "Client sent us a Verification when we aren't syncing.")

            of MessageType.BlockRequest:
                #Grab our chain height and parse the requested hash.
                var
                    height: int = mainFunctions.merit.getHeight()
                    req: Hash[384]
                    res: Block
                try:
                    req = msg.message.toHash(384)
                except ValueError as e:
                    raise newException(ClientError, "`BlockRequest` contained an invalid hash: " & e.msg)

                try:
                    if req.empty:
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
                    except IndexError as e:
                        fcRaise e
                    except SocketError as e:
                        fcRaise e
                    except ClientError as e:
                        fcRaise e
                    except Exception as e:
                        doAssert(false, "Sending `DataMissing` in response to a `BlockRequest` threw an Exception despite catching all thrown Exceptions: " & e.msg)
                    return

                #Since we have the Block, serialize it.
                var serialized: string = res.serialize()

                #Send it.
                try:
                    await network.clients.reply(
                        msg,
                        newMessage(
                            MessageType.Block,
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
                    doAssert(false, "Sending a block in response to a `BlockRequest` threw an Exception despite catching all thrown Exceptions: " & e.msg)

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

                height = mainFunctions.consensus.getMeritHolderHeight(key)
                if height <= nonce:
                    try:
                        await network.clients.reply(
                            msg,
                            newMessage(MessageType.DataMissing)
                        )
                    except IndexError as e:
                        fcRaise e
                    except SocketError as e:
                        fcRaise e
                    except ClientError as e:
                        fcRaise e
                    except Exception as e:
                        doAssert(false, "Sending `DataMissing` in response to a `ElementRequest` threw an Exception despite catching all thrown Exceptions: " & e.msg)
                    return

                try:
                    await network.clients.reply(
                        msg,
                        newMessage(
                            MessageType.Verification,
                            mainFunctions.consensus.getElement(key, nonce).serialize(false)
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

            of MessageType.EntryRequest:
                #Declare the Entry and a MessageType used to send it with.
                var
                    entry: Entry
                    msgType: MessageType

                try:
                    #Try to get the Entry.
                    entry = mainFunctions.lattice.getEntryByHash(msg.message.toHash(384))
                except ValueError as e:
                    raise newException(ClientError, "`EntryRequest` contained an invalid hash: " & e.msg)
                except IndexError:
                    #If that failed, return DataMissing.
                    try:
                        await network.clients.reply(
                            msg,
                            newMessage(MessageType.DataMissing)
                        )
                    except IndexError as e:
                        fcRaise e
                    except SocketError as e:
                        fcRaise e
                    except ClientError as e:
                        fcRaise e
                    except Exception as e:
                        doAssert(false, "Sending `DataMissing` in response to a `EntryRequest` threw an Exception despite catching all thrown Exceptions: " & e.msg)

                #Verify we didn't get a Mint, which should not be transmitted.
                if entry.descendant == EntryType.Mint:
                    #Return DataMissing.
                    try:
                        await network.clients.reply(
                            msg,
                            newMessage(MessageType.DataMissing)
                        )
                    except IndexError as e:
                        fcRaise e
                    except SocketError as e:
                        fcRaise e
                    except ClientError as e:
                        fcRaise e
                    except Exception as e:
                        doAssert(false, "Sending `DataMissing` in response to a `EntryRequest` threw an Exception despite catching all thrown Exceptions: " & e.msg)

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
                try:
                    await network.clients.reply(
                        msg,
                        newMessage(
                            msgType,
                            entry.serialize()
                        )
                    )
                except IndexError as e:
                    fcRaise e
                except SocketError as e:
                    fcRaise e
                except ClientError as e:
                    fcRaise e
                except Exception as e:
                    doAssert(false, "Sending an Entry in response to a `EntryRequest` threw an Exception despite catching all thrown Exceptions: " & e.msg)

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
                    except IndexError as e:
                        fcRaise e
                    except SocketError as e:
                        fcRaise e
                    except ClientError as e:
                        fcRaise e
                    except Exception as e:
                        doAssert(false, "Sending `DataMissing` in response to a `GetBlockHash` threw an Exception despite catching all thrown Exceptions: " & e.msg)
                    return

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
                except BLSError as e:
                    raise newException(InvalidMessageError, "Claim contained an invalid BLS Public Key: " & e.msg)
                except EdPublicKeyError as e:
                    raise newException(InvalidMessageError, "Claim contained an invalid ED25519 Public Key: " & e.msg)

                try:
                    mainFunctions.lattice.addClaim(claim)
                except ValueError as e:
                    raise newException(InvalidMessageError, "Adding the Claim failed due to a ValueError: " & e.msg)
                except IndexError as e:
                    raise newException(InvalidMessageError, "Adding the Claim failed due to a IndexError: " & e.msg)
                except GapError:
                    return
                except AddressError as e:
                    raise newException(InvalidMessageError, "Adding the Claim failed due to a AddressError: " & e.msg)
                except BLSError as e:
                    raise newException(InvalidMessageError, "Adding the Claim failed due to a BLSError: " & e.msg)
                except EdPublicKeyError as e:
                    raise newException(InvalidMessageError, "Adding the Claim failed due to a EdPublicKeyError: " & e.msg)
                except DataExists:
                    return

            of MessageType.Send:
                var send: Send
                try:
                    send = msg.message.parseSend()
                except ArgonError as e:
                    raise newException(InvalidMessageError, "Parsing the Send caused an ArgonError: " & e.msg)
                except EdPublicKeyError as e:
                    raise newException(InvalidMessageError, "Send contained an invalid ED25519 Public Key: " & e.msg)

                try:
                    mainFunctions.lattice.addSend(send)
                except ValueError as e:
                    raise newException(InvalidMessageError, "Adding the Send failed due to a ValueError: " & e.msg)
                except IndexError as e:
                    raise newException(InvalidMessageError, "Adding the Send failed due to a IndexError: " & e.msg)
                except GapError:
                    return
                except AddressError as e:
                    raise newException(InvalidMessageError, "Adding the Send failed due to a AddressError: " & e.msg)
                except EdPublicKeyError as e:
                    raise newException(InvalidMessageError, "Adding the Send failed due to a EdPublicKeyError: " & e.msg)
                except DataExists:
                    return

            of MessageType.Receive:
                var recv: Receive
                try:
                    recv = msg.message.parseReceive()
                except EdPublicKeyError as e:
                    raise newException(InvalidMessageError, "Receive contained an invalid ED25519 Public Key: " & e.msg)

                try:
                    mainFunctions.lattice.addReceive(recv)
                except ValueError as e:
                    raise newException(InvalidMessageError, "Adding the Receive failed due to a ValueError: " & e.msg)
                except IndexError as e:
                    raise newException(InvalidMessageError, "Adding the Receive failed due to a IndexError: " & e.msg)
                except GapError:
                    return
                except AddressError as e:
                    raise newException(InvalidMessageError, "Adding the Receive failed due to a AddressError: " & e.msg)
                except EdPublicKeyError as e:
                    raise newException(InvalidMessageError, "Adding the Receive failed due to a EdPublicKeyError: " & e.msg)
                except DataExists:
                    return

            of MessageType.Data:
                var data: Data
                try:
                    data = msg.message.parseData()
                except ValueError as e:
                    raise newException(InvalidMessageError, "Parsing the Data failed due to a ValueError: " & e.msg)
                except ArgonError as e:
                    raise newException(InvalidMessageError, "Parsing the Data failed due to an ArgonError: " & e.msg)
                except EdPublicKeyError as e:
                    raise newException(InvalidMessageError, "Data contained an invalid ED25519 Public Key: " & e.msg)

                try:
                    mainFunctions.lattice.addData(data)
                except ValueError as e:
                    raise newException(InvalidMessageError, "Adding the Data failed due to a ValueError: " & e.msg)
                except IndexError as e:
                    raise newException(InvalidMessageError, "Adding the Data failed due to a IndexError: " & e.msg)
                except GapError:
                    return
                except AddressError as e:
                    raise newException(InvalidMessageError, "Adding the Data failed due to a AddressError: " & e.msg)
                except EdPublicKeyError as e:
                    raise newException(InvalidMessageError, "Adding the Data failed due to a EdPublicKeyError: " & e.msg)
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
                except IndexError as e:
                    raise newException(InvalidMessageError, "Adding the SignedVerification failed due to a IndexError: " & e.msg)
                except GapError:
                    return
                except BLSError as e:
                    raise newException(InvalidMessageError, "Adding the SignedVerification failed due to a BLSError: " & e.msg)
                except DataExists:
                    return

            of MessageType.Block:
                var newBlock: Block
                try:
                    newBlock = msg.message.parseBlock()
                except ValueError as e:
                    raise newException(InvalidMessageError, "Block didn't contain a valid hash: " & e.msg)
                except ArgonError as e:
                    raise newException(InvalidMessageError, "Parsing the Block caused an ArgonError: " & e.msg)
                except BLSError as e:
                    raise newException(InvalidMessageError, "Block contained an invalid BLS Public Key: " & e.msg)

                try:
                    await mainFunctions.merit.addBlock(newBlock)
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
