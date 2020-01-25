include PeerSendRecv

#Service bits.
const SERVER_SERVICE: uint8 = 0b10000000

#Handshake.
proc handshake*(
    peer: Peer,
    id: int,
    protocol: int,
    server: bool,
    port: int,
    tail: Hash[256]
): Future[Hash[256]] {.forceCheck: [
    PeerError
], async.} =
    try:
        #Supported services.
        var services: uint8 = 0
        if server:
            services = services and SERVER_SERVICE

        #Send a handshake.
        await peer.send(
            newMessage(
                MessageType.Handshake,
                char(id) &
                char(protocol) &
                char(services) &
                port.toBinary() &
                tail.toString()
            )
        )

        #Get their handshake back.
        var handshake: Message = await peer.recv()

        #Verify their handshake is a handshake.
        if handshake.content != MessageType.Handshake:
            raise newException(PeerError, "Peer responded to a Handshake with something other than a handshake.")

        #Deserialize their message.
        var handshakeSeq: seq[string] = handshake.message.deserialize(
            BYTE_LEN,
            BYTE_LEN,
            BYTE_LEN,
            PORT_LEN,
            HASH_LEN
        )
        #Verify their Network ID.
        if int(handshakeSeq[0][0]) != id:
            raise newException(PeerError, "Peer responded to a Handshake with a different Network ID.")
        #Verify their Protocol version.
        if int(handshakeSeq[1][0]) != protocol:
            raise newException(PeerError, "Peer responded to a Handshake with a different Protocol Version.")

        #Set the service flags.
        if (uint8(handshakeSeq[2][0]) and SERVER_SERVICE) == SERVER_SERVICE:
            peer.server = true

        #If the Peer is a server, grab their port.
        if peer.server:
            peer.port = handshakeSeq[3].fromBinary()

        #Return their tail.
        try:
            result = handshakeSeq[4].toHash(256)
        except ValueError as e:
            doAssert(false, "Couldn't turn a 32-byte string into a 32-byte hash: " & e.msg)
    except PeerError as e:
        raise e
    except Exception as e:
        doAssert(false, "Handshaking with a Peer threw an Exception despite catching all thrown Exceptions: " & e.msg)
