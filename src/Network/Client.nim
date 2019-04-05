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

#Message and Client object.
import objects/MessageObj
import objects/ClientObj

#Export the Client object.
export ClientObj

#Networking standard libs.
import asyncdispatch, asyncnet

#Receive a message.
proc recv*(client: Client): Future[Message] {.async.} =
    var
        content: MessageType
        size: int
        msg: string

    #Receive the content type.
    msg = await client.socket.recv(1)
    #If the message length is 0, because the client disconnected...
    if msg.len == 0:
        #Close the Client.
        client.socket.close()
        #Raise an error.
        raise newException(SocketError, "Client disconnected.")
    content = MessageType(msg[0])

    #Switch based on the content to determine the Message Size.
    case content:
        of MessageType.Handshake:
            size = BYTE_LEN + BYTE_LEN + INT_LEN

        of MessageType.Syncing:
            size = 0
        of MessageType.BlockRequest:
            size = INT_LEN
        of MessageType.VerificationRequest:
            size = BLS_PUBLIC_KEY_LEN + INT_LEN
        of MessageType.EntryRequest:
            size = HASH_LEN
        of MessageType.DataMissing:
            size = 0
        of MessageType.SyncingOver:
            size = 0

        of MessageType.Claim:
            size = CLAIM_LEN
        of MessageType.Send:
            size = SEND_LEN
        of MessageType.Receive:
            size = RECEIVE_LEN
        of MessageType.Data:
            size = DATA_PREFIX_LEN

        of MessageType.MemoryVerification:
            size = MEMORY_VERIFICATION_LEN
        of MessageType.Block:
            size = BLOCK_HEADER_LEN + INT_LEN
        of MessageType.Verification:
            size = VERIFICATION_LEN

    #Now that we know how long the message is, get it (as long as there is one).
    if size > 0:
        msg = await client.socket.recv(size)

    #If this is a MessageType with more data...
    case content:
        of MessageType.Data:
            var len: int = int(msg[^1])
            size += len
            msg &= await client.socket.recv(len)
            size += DATA_SUFFIX_LEN
            msg &= await client.socket.recv(DATA_SUFFIX_LEN)
        of MessageType.Block:
            var quantity: int = msg.substr(msg.len - 4).fromBinary()
            size += (quantity * VERIFIER_INDEX_LEN) + BYTE_LEN
            msg &= await client.socket.recv((quantity * VERIFIER_INDEX_LEN) + BYTE_LEN)
            quantity = int(msg[^1])
            size += quantity * MINER_LEN
            msg &= await client.socket.recv(quantity * MINER_LEN)
        else:
            discard

    #Verify the length.
    if msg.len != size:
        raise newException(SocketError, "Didn't get a full message.")

    #Create a proper Message and return it.
    result = newMessage(
        client.id,
        content,
        uint(size),
        msg
    )

#Send a message.
proc send*(client: Client, msg: Message) {.async.} =
    #Make sure the client is open.
    if not client.socket.isClosed():
        try:
            await client.socket.send($msg)
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
    await client.send(
        newMessage(
            MessageType.Handshake,
            char(id) & char(protocol) & height.toBinary().pad(INT_LEN)
        )
    )

    #Get their handshake back.
    var handshake: Message = await client.recv()
    #Verify their handshake is a handshake.
    if handshake.content != MessageType.Handshake:
        return

    #Deserialize their message.
    var handshakeSeq: seq[string] = handshake.message.deserialize(
        BYTE_LEN,
        BYTE_LEN,
        INT_LEN
    )
    #Verify their Network ID.
    if uint(handshakeSeq[0][0]) != id:
        return
    #Verify their Protocol version.
    if uint(handshakeSeq[1][0]) != protocol:
        return

    #Get their Blockchain height.
    var theirHeight: uint = uint(handshakeSeq[2].fromBinary())

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
    await client.send(newMessage(MessageType.Syncing))

    #Update our state.
    client.ourState = ClientState.Syncing

#Sync an Entry.
proc syncEntry*(client: Client, hash: string): Future[SyncEntryResponse] {.async.} =
    #If we're not syncing, raise an error.
    if client.ourState != ClientState.Syncing:
        raise newException(SyncConfigError, "This Client isn't configured to sync data.")

    #Send the request.
    await client.send(newMessage(MessageType.EntryRequest, hash))

    #Get their response.
    var msg: Message = await client.recv()

    case msg.content:
        of MessageType.Claim:
            return newSyncEntryResponse(
                msg.message.parseClaim()
            )

        of MessageType.Send:
            return newSyncEntryResponse(
                msg.message.parseSend()
            )

        of MessageType.Receive:
            return newSyncEntryResponse(
                msg.message.parseReceive()
            )

        of MessageType.Data:
            return newSyncEntryResponse(
                msg.message.parseData()
            )

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
    await client.send(
        newMessage(
            MessageType.VerificationRequest,
            verifier & nonce.toBinary().pad(INT_LEN)
        )
    )

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
    await client.send(newMessage(MessageType.BlockRequest, nonce.toBinary().pad(INT_LEN)))
    echo "Asked for Block."

    #Get their response.
    var msg: Message = await client.recv()
    echo "Received Block"

    case msg.content:
        of MessageType.Block:
            echo "Got Block"
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
    await client.send(newMessage(MessageType.SyncingOver))

    #Update our state.
    client.ourState = ClientState.Ready
