include ClientHandshake

#Tell the Client we're syncing.
proc startSyncing*(
    client: Client
) {.forceCheck: [
    ClientError
], async.} =
    #Increment syncLevels.
    inc(client.syncLevels)

    #If we're already syncing, return.
    if client.syncLevels != 1:
        return

    try:
        #Send that we're syncing.
        await client.send(newMessage(MessageType.Syncing))
        var sentReq: uint32 = getTime()

        #Discard every message until we get a SyncingAcknowledged.
        var msg: Message
        while msg.content != SyncingAcknowledged:
            #If the client doesn't send a SyncingAcknowledged in time, raise an error.
            if getTime() > sentReq + 2:
                raise newException(ClientError, "Client never responded to the fact we were syncing.")

            msg = await client.recv()
    except ClientError as e:
        raise e
    except Exception as e:
        doAssert(false, "Starting Syncing with a Client threw an Exception despite catching all thrown Exceptions: " & e.msg)

#Sync a Transaction.
proc syncTransaction*(
    client: Client,
    hash: Hash[256],
    sendDiff: Hash[256],
    dataDiff: Hash[256]
): Future[Transaction] {.forceCheck: [
    ClientError,
    DataMissing,
    Spam
], async.} =
    try:
        #Send the request.
        await client.send(newMessage(MessageType.TransactionRequest, hash.toString()))
        client.pendingSyncRequest = true

        #Get their response.
        var msg: Message = await client.recv()
        client.pendingSyncRequest = false

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
                    raise newException(ClientError, "Client didn't respond properly to our TransactionRequest.")
        except ValueError as e:
            raise newException(ClientError, "Client didn't respond with a valid Transaction to our TransactionRequest, as pointed out by a ValueError: " & e.msg)

        #Verify the received data is what was requested.
        if result.hash != hash:
            raise newException(ClientError, "Client sent us the wrong Transaction.")
    except ClientError as e:
        raise e
    except DataMissing as e:
        raise e
    except Spam as e:
        if e.hash != hash:
            raise newException(ClientError, "Client sent us the wrong Transaction.")
        raise e
    except Exception as e:
        doAssert(false, "Sending a `TransactionRequest` and receiving the response threw an Exception despite catching all thrown Exceptions: " & e.msg)

#Sync Verification Packets.
proc syncVerificationPackets*(
    client: Client,
    blockHash: Hash[256],
    sketchHashes: seq[uint64],
    sketchSalt: string
): Future[seq[VerificationPacket]] {.forceCheck: [
    ClientError,
    DataMissing
], async.} =
    try:
        #Send the request.
        var req: string = blockHash.toString() & sketchHashes.len.toBinary(INT_LEN)
        for hash in sketchHashes:
            req &= hash.toBinary(SKETCH_HASH_LEN)
        await client.send(newMessage(MessageType.SketchHashRequests, req))
        client.pendingSyncRequest = true

        for sketchHash in sketchHashes:
            #Get their response.
            var msg: Message = await client.recv()

            #Parse the response.
            try:
                case msg.content:
                    of MessageType.VerificationPacket:
                        result.add(msg.message.parseVerificationPacket())
                    of MessageType.DataMissing:
                        raise newException(DataMissing, "Client didn't have the requested VerificationPacket.")
                    else:
                        raise newException(ClientError, "Client didn't respond properly to our SketchHashRequests.")
            except ValueError as e:
                raise newException(ClientError, "Client didn't respond with a valid VerificationPacket to our SketchHashRequests, as pointed out by a ValueError: " & e.msg)

            if sketchHash(sketchSalt, result[^1]) != sketchHash:
                raise newException(ClientError, "Client didn't respond with the right VerificationPacket for our SketchHashRequests.")
        client.pendingSyncRequest = false
    except ClientError as e:
        raise e
    except DataMissing as e:
        raise e
    except Exception as e:
        doAssert(false, "Sending a `SketchHashRequests` and receiving the responses threw an Exception despite catching all thrown Exceptions: " & e.msg)

#Sync Sketch Hashes.
proc syncSketchHashes*(
    client: Client,
    hash: Hash[256],
    sketchCheck: Hash[256]
): Future[seq[uint64]] {.forceCheck: [
    ClientError,
    DataMissing
], async.} =
    try:
        #Send the request.
        await client.send(newMessage(MessageType.SketchHashesRequest, hash.toString()))
        client.pendingSyncRequest = true

        #Get the response.
        var msg: Message = await client.recv()
        client.pendingSyncRequest = false

        #Parse out the sketch hashes.
        result = newSeq[uint64](msg.message[0 ..< 4].fromBinary())
        for i in 0 ..< result.len:
            result[i] = uint64(msg.message[4 + (i * 8) ..< 12 + (i * 8)].fromBinary())

        #Sort the result.
        result.sort(SortOrder.Descending)

        #Verify the sketchCheck Merkle.
        try:
            sketchCheck.verifySketchCheck(result)
        except ValueError as e:
            raise newException(ClientError, e.msg)
    except ClientError as e:
        raise e
    except DataMissing as e:
        raise e
    except Exception as e:
        doAssert(false, "Sending a `SketchHashesRequest` and receiving the responses threw an Exception despite catching all thrown Exceptions: " & e.msg)

#Sync a BlockBody.
proc syncBlockBody*(
    client: Client,
    hash: Hash[256]
): Future[SketchyBlockBody] {.forceCheck: [
    ClientError,
    DataMissing
], async.} =
    try:
        #Send the request.
        await client.send(newMessage(MessageType.BlockBodyRequest, hash.toString()))
        client.pendingSyncRequest = true

        #Get their response.
        var msg: Message = await client.recv()
        client.pendingSyncRequest = false

        #Parse the response.
        try:
            case msg.content:
                of MessageType.BlockBody:
                    result = msg.message.parseBlockBody()
                of MessageType.DataMissing:
                    raise newException(DataMissing, "Client didn't have the requested BlockBody.")
                else:
                    raise newException(ClientError, "Client didn't respond properly to our BlockBodyRequest.")
        except ValueError as e:
            raise newException(ClientError, "Client didn't respond with a valid BlockBody to our BlockBodyRequest, as pointed out by a ValueError: " & e.msg)
    except ClientError as e:
        raise e
    except DataMissing as e:
        raise e
    except Exception as e:
        doAssert(false, "Sending a `BlockBodyRequest` and receiving the response threw an Exception despite catching all thrown Exceptions: " & e.msg)

#Sync a BlockHeader.
proc syncBlockHeader*(
    client: Client,
    hash: Hash[256]
): Future[BlockHeader] {.forceCheck: [
    ClientError,
    DataMissing
], async.} =
    try:
        #Send the request.
        await client.send(newMessage(MessageType.BlockHeaderRequest, hash.toString()))
        client.pendingSyncRequest = true

        #Get their response.
        var msg: Message = await client.recv()
        client.pendingSyncRequest = false

        #Parse the response.
        try:
            case msg.content:
                of MessageType.BlockHeader:
                    result = msg.message.parseBlockHeader()
                of MessageType.DataMissing:
                    raise newException(DataMissing, "Client didn't have the requested BlockHeader.")
                else:
                    raise newException(ClientError, "Client didn't respond properly to our BlockHeaderRequest.")
        except ValueError as e:
            raise newException(ClientError, "Client didn't respond with a valid BlockHeader to our BlockHeaderRequest, as pointed out by a ValueError: " & e.msg)

        #Verify the received data is what was requested.
        if result.hash != hash:
            raise newException(ClientError, "Client sent us the wrong BlockHeader.")
    except ClientError as e:
        raise e
    except DataMissing as e:
        raise e
    except Exception as e:
        doAssert(false, "Sending a `BlockHeaderRequest` and receiving the response threw an Exception despite catching all thrown Exceptions: " & e.msg)

#Sync a Block List.
proc syncBlockList*(
    client: Client,
    forwards: bool,
    amount: int,
    hash: Hash[256]
): Future[seq[Hash[256]]] {.forceCheck: [
    ClientError,
    DataMissing
], async.} =
    try:
        #Send the request.
        await client.send(newMessage(MessageType.BlockListRequest, (if forwards: '\1' else: '\0') & char(amount - 1) & hash.toString()))
        client.pendingSyncRequest = true

        #Get their response.
        var msg: Message = await client.recv()
        client.pendingSyncRequest = false

        #Parse the response.
        try:
            case msg.content:
                of MessageType.BlockList:
                    for h in countup(1, msg.message.len - 2, 32):
                        result.add(msg.message[h ..< h + 32].toHash(256))
                of MessageType.DataMissing:
                    raise newException(DataMissing, "Client didn't have the requested Block List.")
                else:
                    raise newException(ClientError, "Client didn't respond properly to our BlockListRequest.")
        except ValueError as e:
            doAssert(false, "32-byte string isn't a valid 32-byte hash: " & e.msg)
    except ClientError as e:
        raise e
    except DataMissing as e:
        raise e
    except Exception as e:
        doAssert(false, "Sending a `BlockListRequest` and receiving the response threw an Exception despite catching all thrown Exceptions: " & e.msg)

#Tell the Client we're done syncing.
proc stopSyncing*(
    client: Client
) {.forceCheck: [
    ClientError
], async.} =
    #decrement syncLevels.
    dec(client.syncLevels)

    #If this isn't the last sync level, return.
    if client.syncLevels != 0:
        return

    try:
        #Send that we're done syncing.
        await client.send(newMessage(MessageType.SyncingOver))
    except ClientError as e:
        raise e
    except Exception as e:
        doAssert(false, "Starting Syncing with a Client threw an Exception despite catching all thrown Exceptions: " & e.msg)
