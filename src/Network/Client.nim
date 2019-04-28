#Errors lib.
import ../lib/Errors

#Util lib.
import ../lib/Util

#Hash lib.
import ../lib/Hash

#MinerWallet lib.
import ../Wallet/MinerWallet

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

#Message and Client objectS.
import objects/MessageObj
import objects/ClientObj

#Export the Client object.
export ClientObj

#Networking standard libs.
import asyncdispatch, asyncnet

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
    if int(content) >= int(MessageType.End):
        raise newException(ClientError, "Client sent an invalid Message Type.")

    #Extract the content.
    content = MessageType(msg[0])

    #Switch based on the content to determine the Message Size.
    case content:
        of MessageType.Handshake:
            size = BYTE_LEN + BYTE_LEN + INT_LEN

        of MessageType.Syncing:
            size = 0
        of MessageType.SyncingAcknowledged:
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
        of MessageType.Data:
            var len: int = int(msg[^1])
            size += len

            try:
                msg &= await client.socket.recv(len)
            except Exception as e:
                raise newException(SocketError, "Receiving from the Client's socket threw an Exception: " & e.msg)

            size += DATA_SUFFIX_LEN

            try:
                msg &= await client.socket.recv(DATA_SUFFIX_LEN)
            except Exception as e:
                raise newException(SocketError, "Receiving from the Client's socket threw an Exception: " & e.msg)
        of MessageType.Block:
            var quantity: int = msg.substr(msg.len - 4).fromBinary()
            size += (quantity * VERIFIER_INDEX_LEN) + BYTE_LEN

            try:
                msg &= await client.socket.recv((quantity * VERIFIER_INDEX_LEN) + BYTE_LEN)
            except Exception as e:
                raise newException(SocketError, "Receiving from the Client's socket threw an Exception: " & e.msg)

            quantity = int(msg[^1])
            size += quantity * MINER_LEN

            try:
                msg &= await client.socket.recv(quantity * MINER_LEN)
            except Exception as e:
                raise newException(SocketError, "Receiving from the Client's socket threw an Exception: " & e.msg)
        else:
            discard

    #Verify the length.
    if msg.len != size:
        raise newException(ClientError, "Didn't get a full message.")

    #Create a proper Message and return it.
    result = newMessage(
        client.id,
        content,
        size,
        msg
    )

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
            await client.socket.send($msg)
        except Exception as e:
            raise newException(SocketError, "Couldn't send to a Client: " & e.msg)
    #If it isn't, raise an Error.
    else:
        raise newException(ClientError, "Client was closed.")

#Handshake.
proc handshake*(
    client: Client,
    id: int,
    protocol: int,
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
                char(id) & char(protocol) & height.toBinary().pad(INT_LEN)
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
        INT_LEN
    )
    #Verify their Network ID.
    if int(handshakeSeq[0][0]) != id:
        raise newException(InvalidMessageError, "Client responded to a Handshake with a different Network ID.")
    #Verify their Protocol version.
    if int(handshakeSeq[1][0]) != protocol:
        raise newException(InvalidMessageError, "Client responded to a Handshake with a different Protocol Version.")

    #Get their Blockchain height.
    var theirHeight: int = handshakeSeq[2].fromBinary()

    #If they have more blocks than us, return that we're missing blocks.
    if height < theirHeight:
        return HandshakeState.MissingBlocks

    #Else, return that the handshake is complete.
    result = HandshakeState.Complete

#Tell the Client we're syncing.
proc startSyncing*(
    client: Client
) {.forceCheck: [
    SocketError,
    ClientError
], async.} =
    #If we're already syncing, do nothing.
    if client.ourState == ClientState.Syncing:
        return

    #Send that we're syncing.
    try:
        await client.send(newMessage(MessageType.Syncing))
    except SocketError as e:
        fcRaise e
    except ClientError as e:
        fcRaise e
    except Exception as e:
        doAssert(false, "Sending a `Syncing` to a Client threw an Exception despite catching all thrown Exceptions: " & e.msg)

    #Bool of if we should still wait for a SyncingAcknowledged.
    #Set to false after 5 seconds.
    var shouldWait: bool = true
    try:
        addTimer(
            5000,
            true,
            func (fd: AsyncFD): bool {.forceCheck: [].} =
                shouldWait = false
        )
    except OSError as e:
        doAssert(false, "Couldn't set a timer due to an OSError: " & e.msg)
    except Exception as e:
        doAssert(false, "Couldn't set a timer due to an Exception: " & e.msg)

    #Discard every message until we get a SyncingAcknowledged.
    while shouldWait:
        var msg: Message
        try:
            msg = await client.recv()
        except SocketError as e:
            fcRaise e
        except ClientError as e:
            fcRaise e
        except Exception as e:
            doAssert(false, "Receiving the response to a `Syncing` from a Client threw an Exception despite catching all thrown Exceptions: " & e.msg)

        if msg.content == SyncingAcknowledged:
            break

    #If we broke because shouldWait expired, raise a client error.
    if not shouldWait:
        raise newException(ClientError, "Client never responded to the fact we were syncing.")

    #Update our state.
    client.ourState = ClientState.Syncing

#Sync an Entry.
proc syncEntry*(
    client: Client,
    hash: Hash[384]
): Future[SyncEntryResponse] {.forceCheck: [
    SocketError,
    ClientError,
    SyncConfigError,
    InvalidMessageError,
    DataMissing
], async.} =
    #If we're not syncing, raise an error.
    if client.ourState != ClientState.Syncing:
        raise newException(SyncConfigError, "This Client isn't configured to sync data.")

    #Send the request.
    try:
        await client.send(newMessage(MessageType.EntryRequest, hash.toString()))
    except SocketError as e:
        fcRaise e
    except ClientError as e:
        fcRaise e
    except Exception as e:
        doAssert(false, "Sending an `EntryRequest` to a Client threw an Exception despite catching all thrown Exceptions: " & e.msg)

    #Get their response.
    var msg: Message
    try:
        msg = await client.recv()
    except SocketError as e:
        fcRaise e
    except ClientError as e:
        fcRaise e
    except Exception as e:
        doAssert(false, "Receiving the response to an `EntryRequest` from a Client threw an Exception despite catching all thrown Exceptions: " & e.msg)

    #Parse the response.
    try:
        case msg.content:
            of MessageType.Claim:
                result = newSyncEntryResponse(
                    msg.message.parseClaim()
                )

            of MessageType.Send:
                result = newSyncEntryResponse(
                    msg.message.parseSend()
                )

            of MessageType.Receive:
                result = newSyncEntryResponse(
                    msg.message.parseReceive()
                )

            of MessageType.Data:
                result = newSyncEntryResponse(
                    msg.message.parseData()
                )

            of MessageType.DataMissing:
                raise newException(DataMissing, "Client didn't have the requested Entry.")

            else:
                raise newException(InvalidMessageError, "Client didn't respond properly to our EntryRequest.")
    except ValueError as e:
        raise newException(InvalidMessageError, "Client didn't respond with a valid Entry to our EntryRequest, as pointed out by a ValueError: " & e.msg)
    except ArgonError as e:
        raise newException(InvalidMessageError, "Client didn't respond with a valid Entry to our EntryRequest, as pointed out by a ArgonError: " & e.msg)
    except BLSError as e:
        raise newException(InvalidMessageError, "Client didn't respond with a valid Entry to our EntryRequest, as pointed out by a BLSError: " & e.msg)
    except EdPublicKeyError as e:
        raise newException(InvalidMessageError, "Client didn't respond with a valid Entry to our EntryRequest, as pointed out by a EdPublicKeyError: " & e.msg)
    except InvalidMessageError as e:
        fcRaise e
    except DataMissing as e:
        fcRaise e

#Sync a Verification.
proc syncVerification*(
    client: Client,
    verifier: BLSPublicKey,
    nonce: int
): Future[Verification] {.forceCheck: [
    SocketError,
    ClientError,
    SyncConfigError,
    InvalidMessageError,
    DataMissing
], async.} =
    #If we're not syncin/g, raise an error.
    if client.ourState != ClientState.Syncing:
        raise newException(SyncConfigError, "This Client isn't configured to sync data.")

    #Send the request.
    try:
        await client.send(
            newMessage(
                MessageType.VerificationRequest,
                verifier.toString() & nonce.toBinary().pad(INT_LEN)
            )
        )
    except SocketError as e:
        fcRaise e
    except ClientError as e:
        fcRaise e
    except Exception as e:
        doAssert(false, "Sending an `VerificationRequest` to a Client threw an Exception despite catching all thrown Exceptions: " & e.msg)

    #Get their response.
    var msg: Message
    try:
        msg = await client.recv()
    except SocketError as e:
        fcRaise e
    except ClientError as e:
        fcRaise e
    except Exception as e:
        doAssert(false, "Receiving the response to an `VerificationRequest` from a Client threw an Exception despite catching all thrown Exceptions: " & e.msg)

    case msg.content:
        of MessageType.Verification:
            try:
                result = msg.message.parseVerification()
            except ValueError as e:
                raise newException(InvalidMessageError, "Client didn't respond with a valid Verification to our VerificationRequest, as pointed out by a ValueError: " & e.msg)
            except BLSError as e:
                raise newException(InvalidMessageError, "Client didn't respond with a valid Verification to our VerificationRequest, as pointed out by a BLSError: " & e.msg)

        of MessageType.DataMissing:
            raise newException(DataMissing, "Client didn't have the requested Verification.")

        else:
            raise newException(InvalidMessageError, "Client didn't respond properly to our VerificationRequest.")

    if (result.verifier != verifier) or (result.nonce != nonce):
        raise newException(InvalidMessageError, "Synced a Verification that we didn't request.")

#Sync a Block.
proc syncBlock*(
    client: Client,
    nonce: int
): Future[Block] {.forceCheck: [
    SocketError,
    ClientError,
    SyncConfigError,
    InvalidMessageError,
    DataMissing
], async.} =
    #If we're not syncing, raise an error.
    if client.ourState != ClientState.Syncing:
        raise newException(SyncConfigError, "This Client isn't configured to sync data.")

    #Send the request.
    try:
        await client.send(newMessage(MessageType.BlockRequest, nonce.toBinary().pad(INT_LEN)))
    except SocketError as e:
        fcRaise e
    except ClientError as e:
        fcRaise e
    except Exception as e:
        doAssert(false, "Sending an `BlockRequest` to a Client threw an Exception despite catching all thrown Exceptions: " & e.msg)

    #Get their response.
    var msg: Message
    try:
        msg = await client.recv()
    except SocketError as e:
        fcRaise e
    except ClientError as e:
        fcRaise e
    except Exception as e:
        doAssert(false, "Receiving the response to an `BlockRequest` from a Client threw an Exception despite catching all thrown Exceptions: " & e.msg)

    case msg.content:
        of MessageType.Block:
            try:
                result = msg.message.parseBlock()
            except ValueError as e:
                raise newException(InvalidMessageError, "Client didn't respond with a valid Block to our BlockRequest, as pointed out by a ValueError: " & e.msg)
            except ArgonError as e:
                raise newException(InvalidMessageError, "Client didn't respond with a valid Block to our BlockRequest, as pointed out by a ArgonError: " & e.msg)
            except BLSError as e:
                raise newException(InvalidMessageError, "Client didn't respond with a valid Block to our BlockRequest, as pointed out by a BLSError: " & e.msg)

        of MessageType.DataMissing:
            raise newException(DataMissing, "Client didn't have the requested Block.")

        else:
            raise newException(InvalidMessageError, "Client didn't respond properly to our BlockRequest.")

#Tell the Client we're done syncing.
proc stopSyncing*(
    client: Client
) {.forceCheck: [
    SocketError,
    ClientError
], async.} =
    #If we're already not syncing, do nothing.
    if client.ourState != ClientState.Syncing:
        return

    #Send that we're done syncing.
    try:
        await client.send(newMessage(MessageType.SyncingOver))
    except SocketError as e:
        fcRaise e
    except ClientError as e:
        fcRaise e
    except Exception as e:
        doAssert(false, "Sending a `SyncingOver` to a Client threw an Exception despite catching all thrown Exceptions: " & e.msg)

    #Update our state.
    client.ourState = ClientState.Ready
