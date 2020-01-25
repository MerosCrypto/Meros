include PeerHandshake

#Sync peers.
proc syncPeers*(
    peer: Peer
): Future[seq[tuple[ip: string, port: int]]] {.forceCheck: [
    PeerError
], async.} =
    try:
        #Send the request.
        await peer.send(newMessage(MessageType.PeersRequest))
        peer.pendingSyncRequest = true

        #Get their response.
        var msg: Message = await peer.recv()
        peer.pendingSyncRequest = false

        #Parse the response.
        if msg.content != MessageType.Peers:
            raise newException(PeerError, "Peer didn't respond with Peers to our PeersRequest.")

        #Add the peer.
        for p in countup(1, msg.message.len - 1, IP_LEN + PORT_LEN):
            result.add((
                ip: msg.message[p ..< p + IP_LEN],
                port: msg.message[p + IP_LEN ..< p + IP_LEN + PORT_LEN].fromBinary()
            ))
    except PeerError as e:
        raise e
    except Exception as e:
        doAssert(false, "Syncing peers threw an Exception despite catching all thrown Exceptions: " & e.msg)

#Sync a Transaction.
proc syncTransaction*(
    peer: Peer,
    hash: Hash[256],
    sendDiff: Hash[256],
    dataDiff: Hash[256]
): Future[Transaction] {.forceCheck: [
    PeerError,
    DataMissing,
    Spam
], async.} =
    try:
        #Send the request.
        await peer.send(newMessage(MessageType.TransactionRequest, hash.toString()))
        peer.pendingSyncRequest = true

        #Get their response.
        var msg: Message = await peer.recv()
        peer.pendingSyncRequest = false

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
                    raise newException(DataMissing, "Peer didn't have the requested Transaction.")
                else:
                    raise newException(PeerError, "Peer didn't respond properly to our TransactionRequest.")
        except ValueError as e:
            raise newException(PeerError, "Peer didn't respond with a valid Transaction to our TransactionRequest, as pointed out by a ValueError: " & e.msg)

        #Verify the received data is what was requested.
        if result.hash != hash:
            raise newException(PeerError, "Peer sent us the wrong Transaction.")
    except PeerError as e:
        raise e
    except DataMissing as e:
        raise e
    except Spam as e:
        if e.hash != hash:
            raise newException(PeerError, "Peer sent us the wrong Transaction.")
        raise e
    except Exception as e:
        doAssert(false, "Sending a `TransactionRequest` and receiving the response threw an Exception despite catching all thrown Exceptions: " & e.msg)

#Sync Verification Packets.
proc syncVerificationPackets*(
    peer: Peer,
    blockHash: Hash[256],
    sketchHashes: seq[uint64],
    sketchSalt: string
): Future[seq[VerificationPacket]] {.forceCheck: [
    PeerError,
    DataMissing
], async.} =
    try:
        #Send the request.
        var req: string = blockHash.toString() & sketchHashes.len.toBinary(INT_LEN)
        for hash in sketchHashes:
            req &= hash.toBinary(SKETCH_HASH_LEN)
        await peer.send(newMessage(MessageType.SketchHashRequests, req))
        peer.pendingSyncRequest = true

        for sketchHash in sketchHashes:
            #Get their response.
            var msg: Message = await peer.recv()

            #Parse the response.
            try:
                case msg.content:
                    of MessageType.VerificationPacket:
                        result.add(msg.message.parseVerificationPacket())
                    of MessageType.DataMissing:
                        raise newException(DataMissing, "Peer didn't have the requested VerificationPacket.")
                    else:
                        raise newException(PeerError, "Peer didn't respond properly to our SketchHashRequests.")
            except ValueError as e:
                raise newException(PeerError, "Peer didn't respond with a valid VerificationPacket to our SketchHashRequests, as pointed out by a ValueError: " & e.msg)

            if sketchHash(sketchSalt, result[^1]) != sketchHash:
                raise newException(PeerError, "Peer didn't respond with the right VerificationPacket for our SketchHashRequests.")
        peer.pendingSyncRequest = false
    except PeerError as e:
        raise e
    except DataMissing as e:
        raise e
    except Exception as e:
        doAssert(false, "Sending a `SketchHashRequests` and receiving the responses threw an Exception despite catching all thrown Exceptions: " & e.msg)

#Sync Sketch Hashes.
proc syncSketchHashes*(
    peer: Peer,
    hash: Hash[256],
    sketchCheck: Hash[256]
): Future[seq[uint64]] {.forceCheck: [
    PeerError,
    DataMissing
], async.} =
    try:
        #Send the request.
        await peer.send(newMessage(MessageType.SketchHashesRequest, hash.toString()))
        peer.pendingSyncRequest = true

        #Get the response.
        var msg: Message = await peer.recv()
        peer.pendingSyncRequest = false

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
            raise newException(PeerError, e.msg)
    except PeerError as e:
        raise e
    except DataMissing as e:
        raise e
    except Exception as e:
        doAssert(false, "Sending a `SketchHashesRequest` and receiving the responses threw an Exception despite catching all thrown Exceptions: " & e.msg)

#Sync a BlockBody.
proc syncBlockBody*(
    peer: Peer,
    hash: Hash[256]
): Future[SketchyBlockBody] {.forceCheck: [
    PeerError,
    DataMissing
], async.} =
    try:
        #Send the request.
        await peer.send(newMessage(MessageType.BlockBodyRequest, hash.toString()))
        peer.pendingSyncRequest = true

        #Get their response.
        var msg: Message = await peer.recv()
        peer.pendingSyncRequest = false

        #Parse the response.
        try:
            case msg.content:
                of MessageType.BlockBody:
                    result = msg.message.parseBlockBody()
                of MessageType.DataMissing:
                    raise newException(DataMissing, "Peer didn't have the requested BlockBody.")
                else:
                    raise newException(PeerError, "Peer didn't respond properly to our BlockBodyRequest.")
        except ValueError as e:
            raise newException(PeerError, "Peer didn't respond with a valid BlockBody to our BlockBodyRequest, as pointed out by a ValueError: " & e.msg)
    except PeerError as e:
        raise e
    except DataMissing as e:
        raise e
    except Exception as e:
        doAssert(false, "Sending a `BlockBodyRequest` and receiving the response threw an Exception despite catching all thrown Exceptions: " & e.msg)

#Sync a BlockHeader.
proc syncBlockHeader*(
    peer: Peer,
    hash: Hash[256]
): Future[BlockHeader] {.forceCheck: [
    PeerError,
    DataMissing
], async.} =
    try:
        #Send the request.
        await peer.send(newMessage(MessageType.BlockHeaderRequest, hash.toString()))
        peer.pendingSyncRequest = true

        #Get their response.
        var msg: Message = await peer.recv()
        peer.pendingSyncRequest = false

        #Parse the response.
        try:
            case msg.content:
                of MessageType.BlockHeader:
                    result = msg.message.parseBlockHeader()
                of MessageType.DataMissing:
                    raise newException(DataMissing, "Peer didn't have the requested BlockHeader.")
                else:
                    raise newException(PeerError, "Peer didn't respond properly to our BlockHeaderRequest.")
        except ValueError as e:
            raise newException(PeerError, "Peer didn't respond with a valid BlockHeader to our BlockHeaderRequest, as pointed out by a ValueError: " & e.msg)

        #Verify the received data is what was requested.
        if result.hash != hash:
            raise newException(PeerError, "Peer sent us the wrong BlockHeader.")
    except PeerError as e:
        raise e
    except DataMissing as e:
        raise e
    except Exception as e:
        doAssert(false, "Sending a `BlockHeaderRequest` and receiving the response threw an Exception despite catching all thrown Exceptions: " & e.msg)

#Sync a Block List.
proc syncBlockList*(
    peer: Peer,
    forwards: bool,
    amount: int,
    hash: Hash[256]
): Future[seq[Hash[256]]] {.forceCheck: [
    PeerError,
    DataMissing
], async.} =
    try:
        #Send the request.
        await peer.send(newMessage(MessageType.BlockListRequest, (if forwards: '\1' else: '\0') & char(amount - 1) & hash.toString()))
        peer.pendingSyncRequest = true

        #Get their response.
        var msg: Message = await peer.recv()
        peer.pendingSyncRequest = false

        #Parse the response.
        try:
            case msg.content:
                of MessageType.BlockList:
                    for h in countup(1, msg.message.len - 2, 32):
                        result.add(msg.message[h ..< h + 32].toHash(256))
                of MessageType.DataMissing:
                    raise newException(DataMissing, "Peer didn't have the requested Block List.")
                else:
                    raise newException(PeerError, "Peer didn't respond properly to our BlockListRequest.")
        except ValueError as e:
            doAssert(false, "32-byte string isn't a valid 32-byte hash: " & e.msg)
    except PeerError as e:
        raise e
    except DataMissing as e:
        raise e
    except Exception as e:
        doAssert(false, "Sending a `BlockListRequest` and receiving the response threw an Exception despite catching all thrown Exceptions: " & e.msg)
