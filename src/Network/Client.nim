#Errors lib.
import ../lib/Errors

#Util lib.
import ../lib/Util

#Serialization common lib.
import Serialize/SerializeCommon

#Messsage and Client object.
import objects/MessageObj
import objects/ClientObj

#Export the Client object.
export ClientObj

#Networking sstandard libs.
import asyncdispatch, asyncnet

#Receive a message.
proc recv*(client: Client, handshake: bool = false): Future[Message] {.async.} =
    var
        header: string
        offset: int = 0
        size: int
        msg: string

    #If this is a handsshake, set an offset of 2.
    if handshake:
        offset = 2

    #Receive the header.
    header = await client.socket.recv(2 + offset)
    #Verify the length.
    if header.len != (2 + offset):
        #If the header length is 0 because the client disconnected...
        if header.len == 0:
            #Close the client.
            client.socket.close()
            #Stop trying to recv.
            return
        #Else, if we got a partial header, raise an exception.
        raise newException(SocketError, "Didn't get a full header.")

    #Define the size.
    size = ord(header[^1])
    #While the last size char is 255, signifying there's more to the size...
    while ord(header[^1]) == 255:
        #Get a new byte.
        header &= await client.socket.recv(1)
        #Add it to the size.
        size += ord(header[^1])

    #Now that we know how long the message is, get it.
    msg = await client.socket.recv(size)
    #Verify the length.
    if msg.len != size:
        raise newException(SocketError, "Didn't get a full message.")

    #Create a Message out of the header/message and return it.
    result = newMessage(
        client.id,
        MessageType(header[0 + offset]),
        uint(size),
        header,
        msg
    )

#Send a messsage.
proc send*(client: Client, msg: Message) {.raises: [AsyncError].} =
    #Make sure the client is open.
    if not client.socket.isClosed():
        try:
            asyncCheck client.socket.send($msg)
        except:
            raise newException(AsyncError, "Couldn't broacast to a Client.")
    #If it isn't, mark the client for disconnection.
    else:
        raise newException(AsyncError, "Client was closed.")

#Handshake.
proc handshake*(
    client: Client,
    id: uint,
    protocol: uint,
    height: uint
): Future[HandshakeState] {.async.} =
    #Set the result to Error in case the Handshake fails.
    result = HandshakeState.Error

    #Send a handshake.
    await client.socket.send(
        char(id) &
        char(protocol) &
        char(MessageType.Handshake) &
        !height.toBinary()
    )

    #Get their handshake back.
    var handshake: Message = await client.recv(true)

    #Verify their handshake is a handshake.
    if handshake.content != MessageType.Handshake:
        return
    #Verify their Network ID.
    if uint(handshake.header[0]) != id:
        return
    #Verify their Protocol version.
    if uint(handshake.header[1]) != protocol:
        return
    #Verify they're not claiming to have over 4 billion blocks.
    if int(handshake.header[3]) > 4:
        return

    #Get their Blockchain height.
    var theirHeight: uint = uint(
        handshake.message.fromBinary()
    )

    #If they have more blocks than us, return that we're missing blocks.
    if height < theirHeight:
        result = HandshakeState.MissingBlocks

    #Else, return that the handshake is complete.
    result = HandshakeState.Complete
