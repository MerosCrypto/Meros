include ClientHandshake

#Tell the Client we're syncing.
proc startSyncing*(
    client: Client
) {.forceCheck: [
    SocketError,
    ClientError
], async.} =
    #Increment syncLevels.
    inc(client.syncLevels)

    #If we're already syncing, return.
    if client.syncLevels != 0:
        return

    #Send that we're syncing.
    try:
        await client.send(newMessage(MessageType.Syncing))
    except SocketError as e:
        fcRaise e
    except ClientError as e:
        fcRaise e
    except Exception as e:
        doAssert(false, "Sending a `Syncing` to a Client threw an Exception despite catching all thrown Exceptions: " & e.msg)

    #Bool of if we should still wait for a SyncingAcknowledged.
    #Set to false after 5 seconds.
    var shouldWait: bool = true
    try:
        addTimer(
            5000,
            true,
            func (
                fd: AsyncFD
            ): bool {.forceCheck: [].} =
                shouldWait = false
        )
    except OSError as e:
        doAssert(false, "Couldn't set a timer due to an OSError: " & e.msg)
    except Exception as e:
        doAssert(false, "Couldn't set a timer due to an Exception: " & e.msg)

    #Discard every message until we get a SyncingAcknowledged.
    while shouldWait:
        var msg: Message
        try:
            msg = await client.recv()
        except SocketError as e:
            fcRaise e
        except ClientError as e:
            fcRaise e
        except Exception as e:
            doAssert(false, "Receiving the response to a `Syncing` from a Client threw an Exception despite catching all thrown Exceptions: " & e.msg)

        if msg.content == SyncingAcknowledged:
            break

    #If we broke because shouldWait expired, raise a client error.
    if not shouldWait:
        raise newException(ClientError, "Client never responded to the fact we were syncing.")

#Sync an Transaction.
proc syncTransaction*(
    client: Client,
    hash: Hash[384],
    sendDiff: Hash[384],
    dataDiff: Hash[384]
): Future[Transaction] {.forceCheck: [
    SocketError,
    ClientError,
    SyncConfigError,
    InvalidMessageError,
    DataMissing,
    Spam
], async.} =
    #If we're not syncing, raise an error.
    if client.syncLevels == 0:
        raise newException(SyncConfigError, "This Client isn't configured to sync data.")

    #Send the request.
    try:
        await client.send(newMessage(MessageType.TransactionRequest, hash.toString()))
    except SocketError as e:
        fcRaise e
    except ClientError as e:
        fcRaise e
    except Exception as e:
        doAssert(false, "Sending an `TransactionRequest` to a Client threw an Exception despite catching all thrown Exceptions: " & e.msg)

    #Get their response.
    var msg: Message
    try:
        msg = await client.recv()
    except SocketError as e:
        fcRaise e
    except ClientError as e:
        fcRaise e
    except Exception as e:
        doAssert(false, "Receiving the response to an `TransactionRequest` from a Client threw an Exception despite catching all thrown Exceptions: " & e.msg)

    #Parse the response.
    try:
        case msg.content:
            of MessageType.Claim:
                result = msg.message.parseClaim()
            of MessageType.Send:
                result = msg.message.parseSend(sendDiff)
            of MessageType.Data:
                result = msg.message.parseData(dataDiff)
            of MessageType.DataMissing:
                raise newException(DataMissing, "Client didn't have the requested Transaction.")
            else:
                raise newException(InvalidMessageError, "Client didn't respond properly to our TransactionRequest.")
    except ValueError as e:
        raise newException(InvalidMessageError, "Client didn't respond with a valid Transaction to our TransactionRequest, as pointed out by a ValueError: " & e.msg)
    except BLSError as e:
        raise newException(InvalidMessageError, "Client didn't respond with a valid Transaction to our TransactionRequest, as pointed out by a BLSError: " & e.msg)
    except EdPublicKeyError as e:
        raise newException(InvalidMessageError, "Client didn't respond with a valid Transaction to our TransactionRequest, as pointed out by a EdPublicKeyError: " & e.msg)
    except InvalidMessageError as e:
        fcRaise e
    except DataMissing as e:
        fcRaise e
    except Spam as e:
        try:
            if e.hash != hash:
                raise newException(ClientError, "Client sent us the wrong Transaction.")
        except ValueError:
            doAssert(false, "Spam status wasn't constructed with a valid hash.")
        fcRaise e

    #Verify the received data is what was requested.
    if result.hash != hash:
        raise newException(ClientError, "Client sent us the wrong Transaction.")

#Sync a VerificationPacket.
proc syncVerificationPacket*(
    client: Client,
    hash: Hash[384]
): Future[VerificationPacket] {.forceCheck: [], async.} =
    doAssert(false, "Syncing a VerificationPacket is not supported.")

#Sync a Block Body.
proc syncBlockBody*(
    client: Client,
    hash: Hash[384]
): Future[BlockBody] {.forceCheck: [
    SocketError,
    ClientError,
    SyncConfigError,
    InvalidMessageError,
    DataMissing
], async.} =
    #If we're not syncing, raise an error.
    if client.syncLevels == 0:
        raise newException(SyncConfigError, "This Client isn't configured to sync data.")

    try:
        await client.send(newMessage(MessageType.BlockBodyRequest, hash.toString()))
    except SocketError as e:
        fcRaise e
    except ClientError as e:
        fcRaise e
    except Exception as e:
        doAssert(false, "Sending an `BlockBodyRequest` to a Client threw an Exception despite catching all thrown Exceptions: " & e.msg)

    #Get their response.
    var msg: Message
    try:
        msg = await client.recv()
    except SocketError as e:
        fcRaise e
    except ClientError as e:
        fcRaise e
    except Exception as e:
        doAssert(false, "Receiving the response to an `BlockBodyRequest` from a Client threw an Exception despite catching all thrown Exceptions: " & e.msg)

    #Grab the body.
    case msg.content:
        of MessageType.BlockBody:
            try:
                result = msg.message.parseBlockBody()
            except ValueError as e:
                raise newException(InvalidMessageError, "Client didn't respond with a valid BlockBody to our `BlockBodyRequest`, as pointed out by a ValueError: " & e.msg)
            except BLSError as e:
                raise newException(InvalidMessageError, "Client didn't respond with a valid BlockBody to our `BlockBodyRequest`, as pointed out by a BLSError: " & e.msg)

        of MessageType.DataMissing:
            raise newException(DataMissing, "Client didn't have the requested BlockBody.")

        else:
            raise newException(InvalidMessageError, "Client didn't respond properly to our `BlockBodyRequest`.")

#Sync a Block.
proc syncBlock*(
    client: Client,
    hash: Hash[384]
): Future[Block] {.forceCheck: [
    SocketError,
    ClientError,
    SyncConfigError,
    InvalidMessageError,
    DataMissing
], async.} =
    #If we're not syncing, raise an error.
    if client.syncLevels == 0:
        raise newException(SyncConfigError, "This Client isn't configured to sync data.")

    #Get the BlockHeader.
    try:
        await client.send(newMessage(MessageType.BlockHeaderRequest, hash.toString()))
    except SocketError as e:
        fcRaise e
    except ClientError as e:
        fcRaise e
    except Exception as e:
        doAssert(false, "Sending an `BlockHeaderRequest` to a Client threw an Exception despite catching all thrown Exceptions: " & e.msg)

    #Get their response.
    var msg: Message
    try:
        msg = await client.recv()
    except SocketError as e:
        fcRaise e
    except ClientError as e:
        fcRaise e
    except Exception as e:
        doAssert(false, "Receiving the response to an `BlockHeaderRequest` from a Client threw an Exception despite catching all thrown Exceptions: " & e.msg)

    #Grab the header.
    var header: BlockHeader
    case msg.content:
        of MessageType.BlockHeader:
            try:
                header = msg.message.parseBlockHeader()
            except ValueError as e:
                raise newException(InvalidMessageError, "Client didn't respond with a valid BlockHeader to our `BlockHeaderRequest`, as pointed out by a ValueError: " & e.msg)
            except BLSError as e:
                raise newException(InvalidMessageError, "Client didn't respond with a valid BlockHeader to our `BlockHeaderRequest`, as pointed out by a BLSError: " & e.msg)

        of MessageType.DataMissing:
            raise newException(DataMissing, "Client didn't have the requested BlockHeader.")

        else:
            raise newException(InvalidMessageError, "Client didn't respond properly to our `BlockHeaderRequest`.")

    #Verify the received data is what was requested.
    if header.hash != hash:
        raise newException(ClientError, "Client sent us the wrong BlockHeader.")

    #Get the BlockBody.
    var body: BlockBody
    try:
        body = await client.syncBlockBody(header.hash)
    except ValueError as e:
        raise newException(InvalidMessageError, e.msg)
    except SocketError as e:
        fcRaise e
    except ClientError as e:
        fcRaise e
    except SyncConfigError as e:
        fcRaise e
    except InvalidMessageError as e:
        fcRaise e
    except DataMissing as e:
        fcRaise e
    except Exception as e:
        doAssert(false, "Syncing a BlockBody threw an Exception despite catching all thrown Exceptions: " & e.msg)

    #Return the Block.
    result = newBlockObj(header, body)

#Tell the Client we're done syncing.
proc stopSyncing*(
    client: Client
) {.forceCheck: [
    SocketError,
    ClientError
], async.} =
    #decrement syncLevels.
    dec(client.syncLevels)

    #If this isn't the last sync level, return.
    if client.syncLevels != 1:
        return

    #Send that we're done syncing.
    try:
        await client.send(newMessage(MessageType.SyncingOver))
    except SocketError as e:
        fcRaise e
    except ClientError as e:
        fcRaise e
    except Exception as e:
        doAssert(false, "Sending a `SyncingOver` to a Client threw an Exception despite catching all thrown Exceptions: " & e.msg)
