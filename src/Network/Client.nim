#Errors lib.
import ../lib/Errors

#Util lib.
import ../lib/Util

#Lattice lib (for all Entry types).
import ../Database/Lattice/Lattice

#Verifications lib (for Verification/MemoryVerification).
import ../Database/Verifications/Verifications

#Block lib.
import ../Database/Merit/Block as BlockFile

#Serialization common lib.
import Serialize/SerializeCommon

#Serialization parsing libs.
import Serialize/Lattice/ParseClaim
import Serialize/Lattice/ParseSend
import Serialize/Lattice/ParseReceive
import Serialize/Lattice/ParseData

import Serialize/Verifications/ParseVerification
import Serialize/Verifications/ParseMemoryVerification

import Serialize/Merit/ParseBlock

#Messsage and Client object.
import objects/MessageObj
import objects/ClientObj

#Export the Client object.
export ClientObj

#Networking standard libs.
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
proc send*(client: Client, msg: Message) {.raises: [SocketError].} =
    #Make sure the client is open.
    if not client.socket.isClosed():
        try:
            asyncCheck client.socket.send($msg)
        except:
            raise newException(SocketError, "Couldn't broacast to a Client.")
    #If it isn't, mark the client for disconnection.
    else:
        raise newException(SocketError, "Client was closed.")

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
        return HandshakeState.MissingBlocks

    #Else, return that the handshake is complete.
    result = HandshakeState.Complete

#Tell the Client we're syncing.
proc sync*(client: Client) {.async.} =
    #If we're already syncing, do nothing.
    if client.ourState == ClientState.Syncing:
        return

    #Send that we're syncing.
    client.send(newMessage(MessageType.Syncing))

    #Update our state.
    client.ourState = ClientState.Syncing

#Sync an Entry.
proc syncEntry*(client: Client, hash: string): Future[Entry] {.async.} =
    #If we're not syncing, raise an error.
    if client.ourState != ClientState.Syncing:
        raise newException(SyncConfigError, "This Client isn't configured to sync data.")

    #Send the request.
    client.send(newMessage(MessageType.EntryRequest, hash))

    #Get their response.
    var msg: Message = await client.recv()

    case msg.content:
        of MessageType.Claim:
            return msg.message.parseClaim()

        of MessageType.Send:
            return msg.message.parseSend()

        of MessageType.Receive:
            return msg.message.parseReceive()

        of MessageType.Data:
            return msg.message.parseData()

        of MessageType.DataMissing:
            raise newException(DataMissingError, "Client didn't have the requested data.")

        else:
            raise newException(InvalidResponseError, "Client didn't respond properly to our EntryRequest.")

#Sync a Verification.
proc syncVerification*(
    client: Client,
    verifier: string,
    nonce: uint
): Future[Verification] {.async.} =
    #If we're not syncing, raise an error.
    if client.ourState != ClientState.Syncing:
        raise newException(SyncConfigError, "This Client isn't configured to sync data.")

    #Send the request.
    client.send(newMessage(MessageType.VerificationRequest, !verifier & !nonce.toBinary()))

    #Get their response.
    var msg: Message = await client.recv()

    case msg.content:
        of MessageType.Verification:
            return msg.message.parseVerification()

        of MessageType.DataMissing:
            raise newException(DataMissingError, "Client didn't have the requested data.")

        else:
            raise newException(InvalidResponseError, "Client didn't respond properly to our VerificationRequest.")

#Sync a Block.
proc syncBlock*(client: Client, nonce: uint): Future[Block] {.async.} =
    #If we're not syncing, raise an error.
    if client.ourState != ClientState.Syncing:
        raise newException(SyncConfigError, "This Client isn't configured to sync data.")

    #Send the request.
    client.send(newMessage(MessageType.BlockRequest, !nonce.toBinary()))

    #Get their response.
    var msg: Message = await client.recv()

    case msg.content:
        of MessageType.Block:
            return msg.message.parseBlock()

        of MessageType.DataMissing:
            raise newException(DataMissingError, "Client didn't have the requested data.")

        else:
            raise newException(InvalidResponseError, "Client didn't respond properly to our BlockRequest.")

#Tell the Client we're done syncing.
proc syncOver*(client: Client) {.async.} =
    #If we're already not syncing, do nothing.
    if client.ourState != ClientState.Syncing:
        return

    #Send that we're done syncing.
    client.send(newMessage(MessageType.SyncingOver))

    #Update our state.
    client.ourState = ClientState.Ready
