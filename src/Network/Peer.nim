#Errors lib.
import ../lib/Errors

#Util lib.
import ../lib/Util

#Serialization common lib.
import Serialize/SerializeCommon

#Network objects.
import objects/MessageObj
import objects/PeerObj

#Export the Peer object.
export PeerObj

#Element serialize lib. Implements getLength.
import Serialize/Consensus/ParseElement

#Locks standard lib.
import locks

#Networking standard libs.
import asyncdispatch, asyncnet

#Tables lib.
import tables

#Send a message via the Live socket.
proc sendLive*(
    peer: Peer,
    msg: Message
) {.forceCheck: [
    SocketError
], async.} =
    try:
        await peer.live.send(msg.toString())
    except Exception as e:
        peer.sync.safeClose()
        raise newLoggedException(SocketError, "Failed to send to the Peer's live socket: " & e.msg)

#Send a message via the Sync socket.
proc sendSync*(
    peer: Peer,
    msg: Message
) {.forceCheck: [
    SocketError
], async.} =
    try:
        await peer.sync.send(msg.toString())
    except Exception as e:
        peer.sync.safeClose()
        raise newLoggedException(SocketError, "Failed to send to the Peer's live socket: " & e.msg)

#Send a Sync Request.
proc syncRequest*(
    peer: Peer,
    id: int,
    msg: Message
) {.forceCheck: [], async.} =
    while not tryAcquire(peer.syncLock):
        try:
            await sleepAsync(10)
        except Exception as e:
            panic("Couldn't complete an async sleep: " & e.msg)

    peer.requests.add(id)
    try:
        await peer.sendSync(msg)
    except SocketError:
        discard
    except Exception as e:
        panic("Couldn't send to a peer's Sync socket: " & e.msg)

    release(peer.syncLock)

#Receive a message.
proc recv(
    id: int,
    socket: AsyncSocket,
    lengths: Table[MessageType, seq[int]]
): Future[Message] {.forceCheck: [
    SocketError,
    PeerError
], async.} =
    var
        msg: string
        content: MessageType
        size: int

    #Receive the content type.
    try:
        msg = await socket.recv(1)
    except Exception as e:
        raise newLoggedException(SocketError, "Receiving from the Peer's socket threw an Exception: " & e.msg)

    #If the message length is 0, the Peer disconnected.
    if msg.len == 0:
        raise newLoggedException(SocketError, "Peer disconnected.")

    #Make sure the content is valid.
    if not (int(msg[0]) < int(MessageType.End)):
        raise newLoggedException(PeerError, "Peer sent an invalid Message Type: " & $int(msg[0]))

    #Extract the content.
    content = MessageType(msg[0])

    #Get the message's lengths.
    var lens: seq[int]
    try:
        lens = lengths[content]
    except KeyError:
        raise newLoggedException(PeerError, "Peer sent a message for one socket over the other.")

    #Clear the message.
    msg = ""

    #Get the rest of the message.
    var len: int
    for l in 0 ..< lens.len:
        #Grab the next length.
        len = lens[l]
        #If it's negative, multiply this length by the int recvd by the last section and recv that.
        #If the last section was 1, this multiplies it by the byte at that position.
        #If the last section was 4, this multiplies it by the int encoded at that position.
        #If...
        if len < 0:
            len = msg.substr(msg.len - lens[l - 1]).fromBinary() * abs(len)
        #The length has multiple choices depending on the path.
        #Handle this with custom code.
        elif len == 0:
            case content:
                of MessageType.SignedMeritRemoval:
                    var elemI: int = msg.len - 1
                    try:
                        if int(msg[elemI]) == VERIFICATION_PACKET_PREFIX:
                            len = {
                                uint8(VERIFICATION_PACKET_PREFIX)
                            }.getLength(msg[elemI])

                        len += MERIT_REMOVAL_ELEMENT_SET.getLength(
                            msg[elemI],
                            if int(msg[elemI]) == VERIFICATION_PACKET_PREFIX:
                                msg[elemI .. elemI + len].fromBinary()
                            else:
                                0,
                            MERIT_REMOVAL_PREFIX
                        )
                    except ValueError as e:
                        raise newLoggedException(PeerError, e.msg)

                of MessageType.BlockHeader:
                    if int(msg[^1]) == 1:
                        len = BLS_PUBLIC_KEY_LEN
                    elif int(msg[^1]) == 0:
                        len = NICKNAME_LEN
                    else:
                        raise newLoggedException(PeerError, "Peer sent us a Blockheader with an invalid new miner.")

                of MessageType.BlockBody:
                    for _ in 0 ..< msg[msg.len - INT_LEN ..< msg.len].fromBinary():
                        len += BYTE_LEN
                        try:
                            msg &= await socket.recv(len)
                        except Exception as e:
                            raise newLoggedException(PeerError, "Receiving from the Peer's socket threw an Exception: " & e.msg)
                        size += len
                        if msg.len != size:
                            raise newLoggedException(PeerError, "Didn't get a full message. Received " & $msg.len & " when we were supposed to receive " & $size & ".")

                        try:
                            len = BLOCK_ELEMENT_SET.getLength(msg[^1])
                        except ValueError as e:
                            raise newLoggedException(PeerError, e.msg)

                        if int(msg[^1]) == MERIT_REMOVAL_PREFIX:
                            for _ in 0 ..< 2:
                                try:
                                    msg &= await socket.recv(len)
                                except Exception as e:
                                    raise newLoggedException(PeerError, "Receiving from the Peer's socket threw an Exception: " & e.msg)
                                size += len
                                if msg.len != size:
                                    raise newLoggedException(PeerError, "Didn't get a full message. Received " & $msg.len & " when we were supposed to receive " & $size & ".")

                                var elemI: int = msg.len - 1
                                len = 0
                                try:
                                    if int(msg[elemI]) == VERIFICATION_PACKET_PREFIX:
                                        len = {
                                            uint8(VERIFICATION_PACKET_PREFIX)
                                        }.getLength(msg[elemI])

                                    len += MERIT_REMOVAL_ELEMENT_SET.getLength(
                                        msg[elemI],
                                        if int(msg[elemI]) == VERIFICATION_PACKET_PREFIX:
                                            msg[elemI .. elemI + len].fromBinary()
                                        else:
                                            0,
                                        MERIT_REMOVAL_PREFIX
                                    )
                                except ValueError as e:
                                    raise newLoggedException(PeerError, e.msg)
                            dec(len)

                else:
                    panic("Length of 0 was found for a message other than the ones we support.")

        #Recv the data.
        try:
            msg &= await socket.recv(len)
        except Exception as e:
            raise newLoggedException(SocketError, "Receiving from the Peer's socket threw an Exception: " & e.msg)

        #Add the length to the size and verify the size.
        size += len
        if msg.len != size:
            raise newLoggedException(SocketError, "Didn't get a full message. Received " & $msg.len & " when we were supposed to receive " & $size & ".")

    #Create a proper Message to be returned.
    result = newMessage(id, content, msg)

#Receive a message over the Live socket.
proc recvLive*(
    peer: Peer
): Future[Message] {.forceCheck: [
    SocketError,
    PeerError
], async.} =
    #Receive the message.
    try:
        result = await recv(peer.id, peer.live, LIVE_LENS)
    except SocketError as e:
        peer.live.safeClose()
        raise e
    except PeerError as e:
        raise e
    except Exception as e:
        panic("Couldn't receive from the Sync socket despite catching all Exceptions: " & e.msg)

    #Update the time of their last message.
    peer.last = getTime()

#Receive a message over the Sync socket.
proc recvSync*(
    peer: Peer
): Future[Message] {.forceCheck: [
    SocketError,
    PeerError
], async.} =
    #Receive the message.
    try:
        result = await recv(peer.id, peer.sync, SYNC_LENS)
    except SocketError as e:
        peer.sync.safeClose()
        raise e
    except PeerError as e:
        raise e
    except Exception as e:
        panic("Couldn't receive from the Sync socket despite catching all Exceptions: " & e.msg)

    #Update the time of their last message.
    peer.last = getTime()
