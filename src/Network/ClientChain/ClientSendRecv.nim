include ClientImports

#Send a message.
proc send*(
    client: Client,
    msg: Message
) {.forceCheck: [
    SocketError,
    ClientError
], async.} =
    #Make sure the client is open.
    if not client.socket.isClosed():
        try:
            await client.socket.send(msg.toString())
        except Exception as e:
            raise newException(SocketError, "Couldn't send to a Client: " & e.msg)
    #If it isn't, raise an Error.
    else:
        raise newException(ClientError, "Client was closed.")

#Receive a message.
proc recv*(
    client: Client
): Future[Message] {.forceCheck: [
    SocketError,
    ClientError
], async.} =
    var
        content: MessageType
        size: int
        msg: string

    #Receive the content type.
    try:
        msg = await client.socket.recv(1)
    except Exception as e:
        raise newException(SocketError, "Receiving from the Client's socket threw an Exception: " & e.msg)

    #If the message length is 0, because the client disconnected...
    if msg.len == 0:
        raise newException(ClientError, "Client disconnected.")

    #Make sure the content is valid.
    if int(msg[0]) >= int(MessageType.End):
        raise newException(ClientError, "Client sent an invalid Message Type.")

    #Extract the content.
    content = MessageType(msg[0])

    #Switch based on the content to determine the Message Size.
    case content:
        of MessageType.Handshake:
            size = BYTE_LEN + BYTE_LEN + BYTE_LEN + INT_LEN
        of MessageType.BlockHeight:
            size = 4

        of MessageType.Syncing:
            size = 0
        of MessageType.SyncingAcknowledged:
            size = 0
        of MessageType.BlockHeaderRequest:
            size = HASH_LEN
        of MessageType.BlockBodyRequest:
            size = HASH_LEN
        of MessageType.ElementRequest:
            size = BLS_PUBLIC_KEY_LEN + INT_LEN
        of MessageType.TransactionRequest:
            size = HASH_LEN
        of MessageType.GetBlockHash:
            size = INT_LEN
        of MessageType.BlockHash:
            size = HASH_LEN
        of MessageType.DataMissing:
            size = 0
        of MessageType.SyncingOver:
            size = 0

        of MessageType.Claim:
            size = CLAIM_LENS[0]
        of MessageType.Send:
            size = SEND_LENS[0]
        of MessageType.Data:
            size = DATA_PREFIX_LEN

        of MessageType.SignedVerification:
            size = SIGNED_VERIFICATION_LEN
        of MessageType.SignedMeritRemoval:
            size = MERIT_REMOVAL_LENS[0]

        of MessageType.BlockHeader:
            size = BLOCK_HEADER_LEN
        of MessageType.BlockBody:
            size = INT_LEN
        of MessageType.Verification:
            size = VERIFICATION_LEN
        of MessageType.MeritRemoval:
            size = MERIT_REMOVAL_LENS[0]

        of MessageType.End:
            doAssert(false, "Trying to Receive a Message of Type End despite explicitly checking the type was less than End.")

    #Now that we know how long the message is, get it (as long as there is one).
    if size > 0:
        try:
            msg = await client.socket.recv(size)
        except Exception as e:
            raise newException(SocketError, "Receiving from the Client's socket threw an Exception: " & e.msg)
    #If there's not a message, make sure we still clear the header from the variable so the length checks pass.
    else:
        msg = ""

    #If this is a MessageType with more data...
    case content:
        of MessageType.Claim:
            var len: int = (int(msg[0]) * CLAIM_LENS[1]) + CLAIM_LENS[2]
            size += len
            try:
                msg &= await client.socket.recv(len)
            except Exception as e:
                raise newException(SocketError, "Receiving from the Client's socket threw an Exception: " & e.msg)

        of MessageType.Send:
            var len: int = (int(msg[0]) * SEND_LENS[1]) + SEND_LENS[2]
            size += len
            try:
                msg &= await client.socket.recv(len)
            except Exception as e:
                raise newException(SocketError, "Receiving from the Client's socket threw an Exception: " & e.msg)

            len = (int(msg[^1]) * SEND_LENS[3]) + SEND_LENS[4]
            size += len
            try:
                msg &= await client.socket.recv(len)
            except Exception as e:
                raise newException(SocketError, "Receiving from the Client's socket threw an Exception: " & e.msg)

        of MessageType.Data:
            var len: int = int(msg[^1]) + DATA_SUFFIX_LEN
            size += len
            try:
                msg &= await client.socket.recv(len)
            except Exception as e:
                raise newException(SocketError, "Receiving from the Client's socket threw an Exception: " & e.msg)

        of MessageType.SignedMeritRemoval:
            var len: int = MERIT_REMOVAL_LENS[2]
            case int(msg[^1]):
                of VERIFICATION_PREFIX:
                    len += VERIFICATION_LEN - BLS_PUBLIC_KEY_LEN
                of SEND_DIFFICULTY_PREFIX:
                    doAssert(false, "Client sent an unsupport element type.")
                of DATA_DIFFICULTY_PREFIX:
                    doAssert(false, "Client sent an unsupport element type.")
                of GAS_PRICE_PREFIX:
                    doAssert(false, "Client sent an unsupport element type.")
                else:
                    raise newException(ClientError, "Client sent an invalid element type for their MeritRemoval.")
            size += len
            try:
                msg &= await client.socket.recv(len)
            except Exception as e:
                raise newException(SocketError, "Receiving from the Client's socket threw an Exception: " & e.msg)

            len = MERIT_REMOVAL_LENS[4]
            case int(msg[^1]):
                of VERIFICATION_PREFIX:
                    len += VERIFICATION_LEN - BLS_PUBLIC_KEY_LEN
                of SEND_DIFFICULTY_PREFIX:
                    doAssert(false, "Client sent an unsupport element type.")
                of DATA_DIFFICULTY_PREFIX:
                    doAssert(false, "Client sent an unsupport element type.")
                of GAS_PRICE_PREFIX:
                    doAssert(false, "Client sent an unsupport element type.")
                else:
                    raise newException(ClientError, "Client sent an invalid element type for their MeritRemoval.")
            size += len
            try:
                msg &= await client.socket.recv(len)
            except Exception as e:
                raise newException(SocketError, "Receiving from the Client's socket threw an Exception: " & e.msg)

        of MessageType.BlockBody:
            var len: int = (msg.fromBinary() * MERIT_HOLDER_RECORD_LEN) + BYTE_LEN
            size += len
            try:
                msg &= await client.socket.recv(len)
            except Exception as e:
                raise newException(SocketError, "Receiving from the Client's socket threw an Exception: " & e.msg)

            len = int(msg[^1]) * MINER_LEN
            size += len
            try:
                msg &= await client.socket.recv(len)
            except Exception as e:
                raise newException(SocketError, "Receiving from the Client's socket threw an Exception: " & e.msg)

        of MessageType.MeritRemoval:
            var len: int = MERIT_REMOVAL_LENS[2]
            case int(msg[^1]):
                of VERIFICATION_PREFIX:
                    len += VERIFICATION_LEN - BLS_PUBLIC_KEY_LEN
                of SEND_DIFFICULTY_PREFIX:
                    doAssert(false, "Client sent an unsupport element type.")
                of DATA_DIFFICULTY_PREFIX:
                    doAssert(false, "Client sent an unsupport element type.")
                of GAS_PRICE_PREFIX:
                    doAssert(false, "Client sent an unsupport element type.")
                else:
                    raise newException(ClientError, "Client sent an invalid element type for their MeritRemoval.")
            size += len
            try:
                msg &= await client.socket.recv(len)
            except Exception as e:
                raise newException(SocketError, "Receiving from the Client's socket threw an Exception: " & e.msg)

            case int(msg[^1]):
                of VERIFICATION_PREFIX:
                    len = VERIFICATION_LEN - BLS_PUBLIC_KEY_LEN
                of SEND_DIFFICULTY_PREFIX:
                    doAssert(false, "Client sent an unsupport element type.")
                of DATA_DIFFICULTY_PREFIX:
                    doAssert(false, "Client sent an unsupport element type.")
                of GAS_PRICE_PREFIX:
                    doAssert(false, "Client sent an unsupport element type.")
                else:
                    raise newException(ClientError, "Client sent an invalid element type for their MeritRemoval.")
            size += len
            try:
                msg &= await client.socket.recv(len)
            except Exception as e:
                raise newException(SocketError, "Receiving from the Client's socket threw an Exception: " & e.msg)

        else:
            discard

    #Verify the length.
    if msg.len != size:
        raise newException(ClientError, "Didn't get a full message.")

    #Create a proper Message to be returned.
    result = newMessage(
        client.id,
        content,
        size,
        msg
    )

    #Update the time of their last message.
    client.last = getTime()
