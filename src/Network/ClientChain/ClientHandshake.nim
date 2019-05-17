include ClientSendRecv

#Handshake.
proc handshake*(
    client: Client,
    id: int,
    protocol: int,
    server: bool,
    height: int
): Future[HandshakeState] {.forceCheck: [
    SocketError,
    ClientError,
    InvalidMessageError
], async.} =
    #Send a handshake.
    try:
        await client.send(
            newMessage(
                MessageType.Handshake,
                char(id) &
                char(protocol) &
                (if server: char(255) else: char(0)) &
                height.toBinary().pad(INT_LEN)
            )
        )
    except SocketError as e:
        fcRaise e
    except ClientError as e:
        fcRaise e
    except Exception as e:
        doAssert(false, "Sending a handshake to a Client threw an Exception despite catching all thrown Exceptions: " & e.msg)

    #Get their handshake back.
    var handshake: Message
    try:
        handshake = await client.recv()
    except SocketError as e:
        fcRaise e
    except ClientError as e:
        fcRaise e
    except Exception as e:
        doAssert(false, "Receiving a Client's handshake threw an Exception despite catching all thrown Exceptions: " & e.msg)

    #Verify their handshake is a handshake.
    if handshake.content != MessageType.Handshake:
        raise newException(InvalidMessageError, "Client responded to a Handshake with something other than a handshake.")

    #Deserialize their message.
    var handshakeSeq: seq[string] = handshake.message.deserialize(
        BYTE_LEN,
        BYTE_LEN,
        BYTE_LEN,
        INT_LEN
    )
    #Verify their Network ID.
    if int(handshakeSeq[0][0]) != id:
        raise newException(InvalidMessageError, "Client responded to a Handshake with a different Network ID.")
    #Verify their Protocol version.
    if int(handshakeSeq[1][0]) != protocol:
        raise newException(InvalidMessageError, "Client responded to a Handshake with a different Protocol Version.")

    if int(handshakeSeq[2][0]) == 255:
        try:
            client.server = true
        except FinalAttributeError as e:
            doAssert(false, "Set a final attribute twice when handshaking with a Client: " & e.msg)

    #Get their Blockchain height.
    var theirHeight: int = handshakeSeq[3].fromBinary()

    #If they have more blocks than us, return that we're missing blocks.
    if height < theirHeight:
        return HandshakeState.MissingBlocks

    #Else, return that the handshake is complete.
    result = HandshakeState.Complete
