include ClientImports

#Send a message.
proc send*(
    client: Client,
    msg: Message
) {.forceCheck: [
    ClientError
], async.} =
    #Make sure the client is open.
    if not client.socket.isClosed():
        try:
            await client.socket.send(msg.toString())
        except Exception as e:
            raise newException(ClientError, "Couldn't send to a Client: " & e.msg)
    #If it isn't, raise an Error.
    else:
        raise newException(ClientError, "Client was closed.")

#Receive a message.
proc recv*(
    client: Client
): Future[Message] {.forceCheck: [
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
        raise newException(ClientError, "Receiving from the Client's socket threw an Exception: " & e.msg)

    #If the message length is 0, because the client disconnected...
    if msg.len == 0:
        raise newException(ClientError, "Client disconnected.")

    #Make sure the content is valid.
    if not (int(msg[0]) < int(MessageType.End)):
        raise newException(ClientError, "Client sent an invalid Message Type: " & $int(msg[0]))

    #Extract the content.
    content = MessageType(msg[0])

    #Clear the message.
    msg = ""

    #Get the rest of the message.
    var lens: seq[int]
    try:
        lens = MESSAGE_LENS[content]
    except KeyError:
        doAssert(false, "Handling a message without lengths.")

    var
        lastMultiplier: int
        len: int
    for l in 0 ..< lens.len:
        #Grab the next length.
        len = lens[l]
        #If it's negative, multiply this length by the int recvd by the last section and recv that.
        #If the last section was 1, this multiplies it by the byte at that position.
        #If the last section was 4, this multiplies it by the int encoded at that position.
        #If...
        if len < 0:
            if lens[l - 1] > 0:
                lastMultiplier = msg.substr(msg.len - lens[l - 1]).fromBinary()
            len = lastMultiplier * abs(len)
        #The length has multiple choices depending on the path.
        #Handle this with custom code.
        elif len == 0:
            case content:
                of MessageType.SignedMeritRemoval:
                    case int(msg[^1]):
                        of VERIFICATION_PREFIX:
                            len = NICKNAME_LEN + HASH_LEN
                        else:
                            raise newException(ClientError, "Client sent a SignedMeritRemoval with an unknown prefix.")

                of MessageType.BlockHeader:
                    if int(msg[^1]) == 1:
                        len = BLS_PUBLIC_KEY_LEN
                    elif int(msg[^1]) == 0:
                        len = NICKNAME_LEN
                    else:
                        raise newException(ClientError, "Client sent us a Blockheader with an invalid new miner.")

                of MessageType.BlockBody:
                    discard

                else:
                    doAssert(false, "Length of 0 was found for a message other than the ones we support.")

        #Recv the data.
        try:
            msg &= await client.socket.recv(len)
        except Exception as e:
            raise newException(ClientError, "Receiving from the Client's socket threw an Exception: " & e.msg)

        #Add the length to the size and verify the size.
        size += len
        if msg.len != size:
            raise newException(ClientError, "Didn't get a full message. Received " & $msg.len & " when we were supposed to receive " & $size & ".")

    #Create a proper Message to be returned.
    result = newMessage(
        client.id,
        content,
        size,
        msg
    )

    #Update the time of their last message.
    client.last = getTime()
