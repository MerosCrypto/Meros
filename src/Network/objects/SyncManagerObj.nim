#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash and Merkle libs.
import ../../lib/Hash
import ../../lib/Merkle

#Sketcher lib.
import ../../lib/Sketcher

#Block lib.
import ../../Database/Merit/Block

#Elements lib.
import ../../Database/Consensus/Elements/Elements

#Transaction lib.
import ../../Database/Transactions/Transaction as TransactionFile

#GlobalFunctionBox object.
import ../../objects/GlobalFunctionBoxObj

#Message object.
import MessageObj

#SyncRequest object.
import SyncRequestObj

#SketchyBlock object.
import SketchyBlockObj

#Peer lib.
import ../Peer as PeerFile

#Serialization libs.
import ../Serialize/SerializeCommon

import ../Serialize/Merit/SerializeBlockHeader
import ../Serialize/Merit/SerializeBlockBody

import ../Serialize/Consensus/SerializeVerification
import ../Serialize/Consensus/SerializeSendDifficulty
import ../Serialize/Consensus/SerializeDataDifficulty
import ../Serialize/Consensus/SerializeMeritRemoval

import ../Serialize/Transactions/SerializeClaim
import ../Serialize/Transactions/SerializeSend
import ../Serialize/Transactions/SerializeData

import ../Serialize/Merit/ParseBlockHeader
import ../Serialize/Merit/ParseBlockBody

import ../Serialize/Consensus/ParseVerificationPacket

import ../Serialize/Transactions/ParseClaim
import ../Serialize/Transactions/ParseSend
import ../Serialize/Transactions/ParseData

#Chronos external lib.
import chronos

#Algorithm standard lib.
import algorithm

#Sets standard lib.
import sets

#Tables standard lib.
import tables

#SyncManager object.
type SyncManager* = ref object
    #Protocol version.
    protocol: int
    #Network ID.
    network: int
    #Services byte.
    services: char
    #Server port.
    port: int

    #Next usable Request ID.
    id*: int

    #Table of every Peer.
    peers*: TableRef[int, Peer]
    #Ongoing Requests.
    requests*: Table[int, SyncRequest]

    #Global Function Box.
    functions*: GlobalFunctionBox

#Constructor.
func newSyncManager*(
    protocol: int,
    network: int,
    port: int,
    peers: TableRef[int, Peer],
    functions: GlobalFunctionBox
): SyncManager {.forceCheck: [].} =
    SyncManager(
        protocol: protocol,
        network: network,
        port: port,

        id: 0,

        peers: peers,
        requests: initTable[int, SyncRequest](),

        functions: functions
    )

#Update the services byte.
func updateServices*(
    manager: SyncManager,
    service: uint8
) {.forceCheck: [].} =
    manager.services = char(uint8(manager.services) or service)

#Handle a SyncRequest Response.
proc handleResponse[SyncRequestType, ResultType, CheckType](
    manager: SyncManager,
    peer: Peer,
    msg: Message,
    parse: proc (
        serialization: string,
        check: CheckType
    ): ResultType {.raises: [
        ValueError
    ].}
) {.forceCheck: [
    PeerError
].} =
    #Verify there's a Sync Request to check.
    if peer.requests.len == 0:
        raise newLoggedException(PeerError, "Peer sent us data without any pending SyncRequests.")

    #Check if the message is DataMissing.
    if msg.content == MessageType.DataMissing:
        peer.requests.delete(0)
        return

    #Verify the Request is still active.
    if not manager.requests.hasKey(peer.requests[0]):
        peer.requests.delete(0)
        return

    try:
        #Verify this response is valid for the SyncRequest type.
        if not (manager.requests[peer.requests[0]] of SyncRequestType):
            raise newLoggedException(PeerError, "Peer sent us an invalid response to our SyncRequest.")

        #Void result types are used for DataMissing.
        when ResultType is void:
            #Verify the request wasn't for Peers, the only request to now allow DataMissing.
            if manager.requests[peer.requests[0]] of PeersSyncRequest:
                raise newLoggedException(PeerError, "Peer sent us an invalid response to our SyncRequest.")

        when not (ResultType is void):
            #Grab and cast the request.
            var request: SyncRequestType = cast[SyncRequestType](manager.requests[peer.requests[0]])

            #If it's a PeersSyncRequest, append to the pending peers list instead of completing the future.
            when SyncRequestType is PeersSyncRequest:
                try:
                    for peerSuggestion in msg.message.parse():
                        if not request.existing.contains(peerSuggestion.ip):
                            request.pending.add((
                                ip: (
                                    $peerSuggestion.ip[0].fromBinary() & "." &
                                    $peerSuggestion.ip[1].fromBinary() & "." &
                                    $peerSuggestion.ip[2].fromBinary() & "." &
                                    $peerSuggestion.ip[3].fromBinary()
                                ),
                                port: peerSuggestion.port
                            ))
                        request.existing.incl(peerSuggestion.ip)
                except ValueError as e:
                    panic("Parsing peers raised a ValueError: " & e.msg)

                #Mark that this Peer completed.
                dec(request.remaining)

                #If this was the last peer, complete the future.
                if request.remaining == 0:
                    try:
                        request.result.complete(request.pending)
                    except Exception as e:
                        panic("Couldn't complete a Future: " & e.msg)

                #Delete the request from this Peer and return.
                peer.requests.delete(0)
                return
            #Complete the future.
            else:
                try:
                    request.result.complete(msg.message.parse(request.check))
                except ValueError:
                    raise newLoggedException(PeerError, "Peer sent us an unparsable response to our SyncRequest.")
                except Exception as e:
                    panic("Couldn't complete a Future: " & e.msg)
    except KeyError as e:
        panic("Couldn't get a SyncRequest we confirmed we have: " & e.msg)

    #Delete the Request.
    manager.requests.del(peer.requests[0])
    peer.requests.delete(0)

#Handle a new connection.
proc handle*(
    manager: SyncManager,
    peer: Peer
) {.forceCheck: [], async.} =
    #Send our Syncing and get their Syncing.
    var msg: Message
    try:
        await peer.sendSync(newMessage(
            MessageType.Syncing,
            char(manager.protocol) &
            char(manager.network) &
            manager.services &
            manager.port.toBinary(PORT_LEN) &
            manager.functions.merit.getTail().toString()
        ))
        msg = await peer.recvSync()
    except SocketError:
        return
    except PeerError:
        peer.close()
        return
    except Exception as e:
        panic("Handshaking threw an Exception despite catching all thrown Exceptions: " & e.msg)

    if msg.content != MessageType.Syncing:
        peer.close()
        return

    if int(msg.message[0]) != manager.protocol:
        peer.close()
        return

    if int(msg.message[1]) != manager.network:
        peer.close()
        return

    if (uint8(msg.message[2]) and SERVER_SERVICE) == SERVER_SERVICE:
        peer.server = true

    peer.port = msg.message[3 ..< 5].fromBinary()

    #Create an artificial BlockTail message.
    msg = newMessage(MessageType.BlockchainTail, msg.message[5 ..< 37])

    #Receive and handle messages forever.
    var res: Message
    while true:
        res = newMessage(MessageType.End)

        block thisMsg:
            case msg.content:
                of MessageType.Syncing:
                    #Manually send the BlockchainTail now since adding the tail may create Sync Requests.
                    try:
                        await peer.sendSync(newMessage(
                            MessageType.BlockchainTail,
                            manager.functions.merit.getTail().toString()
                        ))
                    except SocketError:
                        return
                    except Exception as e:
                        panic("Failed to reply to a Sync request: " & e.msg)

                    #Add the tail.
                    var tail: Hash[256]
                    try:
                        tail = msg.message[5 ..< 37].toHash(256)
                    except ValueError as e:
                        panic("Couldn't create a 32-byte hash out of a 32-byte value: " & e.msg)

                    try:
                        asyncCheck manager.functions.merit.addBlockByHash(peer, tail)
                    except Exception as e:
                        panic("Adding a Block threw an Exception despite catching all thrown Exceptions: " & e.msg)

                of MessageType.BlockchainTail:
                    #Get the tail.
                    var tail: Hash[256]
                    try:
                        tail = msg.message[0 ..< 32].toHash(256)
                    except ValueError as e:
                        panic("Couldn't turn a 32-byte string into a 32-byte hash: " & e.msg)

                    #Add the Block.
                    try:
                        asyncCheck manager.functions.merit.addBlockByHash(peer, tail)
                    except Exception as e:
                        panic("Adding a Block threw an Exception despite catching all thrown Exceptions: " & e.msg)

                of MessageType.PeersRequest:
                    var peers: seq[Peer] = manager.peers.getPeers(
                        min(manager.peers.len, 4),
                        msg.peer,
                        server = true
                    )

                    res = newMessage(MessageType.Peers, peers.len.toBinary(BYTE_LEN))
                    for peer in peers:
                        res.message &= peer.ip & peer.port.toBinary(PORT_LEN)

                of MessageType.Peers:
                    try:
                        handleResponse[PeersSyncRequest, seq[tuple[ip: string, port: int]], void](
                            manager,
                            peer,
                            msg,
                            proc (
                                serialization: string
                            ): seq[tuple[ip: string, port: int]] {.forceCheck: [].} =
                                result = newSeq[tuple[ip: string, port: int]](serialization[0].fromBinary())
                                for p in 0 ..< result.len:
                                    result[p] = (
                                        ip: serialization[BYTE_LEN + (p * PEER_LEN) ..< BYTE_LEN + (p * PEER_LEN) + IP_LEN],
                                        port: serialization[BYTE_LEN + (p * PEER_LEN) + IP_LEN ..< BYTE_LEN + (p * PEER_LEN) + PEER_LEN].fromBinary()
                                    )
                        )
                    except ValueError as e:
                        panic("Passing a function which can raise ValueError raised a ValueError: " & e.msg)
                    except PeerError:
                        peer.close()
                        return

                of MessageType.BlockListRequest:
                    var
                        list: string = ""
                        last: Hash[256]
                        i: int = -1

                    try:
                        last = msg.message[BYTE_LEN + BYTE_LEN ..< BYTE_LEN + BYTE_LEN + HASH_LEN].toHash(256)
                    except ValueError as e:
                        panic("Couldn't create a 32-byte hash out of a 32-byte value: " & e.msg)

                    try:
                        #Backwards.
                        if int(msg.message[0]) == 0:
                            while i < int(msg.message[1]):
                                last = manager.functions.merit.getBlockHashBefore(last)
                                list &= last.toString()
                                inc(i)
                        #Forwards.
                        elif int(msg.message[0]) == 1:
                            while i < int(msg.message[1]):
                                last = manager.functions.merit.getBlockHashAfter(last)
                                list &= last.toString()
                                inc(i)
                        else:
                            peer.close()
                            return
                    except IndexError:
                        discard

                    if i == -1:
                        res = newMessage(MessageType.DataMissing)
                    else:
                        res = newMessage(MessageType.BlockList, char(i) & list)

                of MessageType.BlockList:
                    try:
                        handleResponse[BlockListSyncRequest, seq[Hash[256]], bool](
                            manager,
                            peer,
                            msg,
                            proc (
                                serialization: string,
                                check: bool
                            ): seq[Hash[256]] {.forceCheck: [].} =
                                #Parse out the hashes.
                                result = newSeq[Hash[256]](1 + int(serialization[0]))
                                for i in 0 ..< result.len:
                                    try:
                                        result[i] = msg.message[BYTE_LEN + (i * HASH_LEN) ..< BYTE_LEN + HASH_LEN + (i * HASH_LEN)].toHash(256)
                                    except ValueError as e:
                                        panic("Couldn't create a 32-byte hash out of a 32-byte value: " & e.msg)
                        )
                    except PeerError:
                        peer.close()
                        return

                of MessageType.BlockHeaderRequest:
                    try:
                        res = newMessage(
                            MessageType.BlockHeader,
                            manager.functions.merit.getBlockByHash(msg.message.toHash(256)).header.serialize()
                        )
                    except ValueError as e:
                        panic("Couln't convert a 32-byte message to a 32-byte hash: " & e.msg)
                    except IndexError:
                        res = newMessage(MessageType.DataMissing)

                of MessageType.BlockBodyRequest:
                    try:
                        var requested: Block = manager.functions.merit.getBlockByHash(msg.message.toHash(256))
                        res = newMessage(MessageType.BlockBody, requested.body.serialize(requested.header.sketchSalt))
                    except ValueError as e:
                        panic("Couln't convert a 32-byte message to a 32-byte hash: " & e.msg)
                    except IndexError:
                        res = newMessage(MessageType.DataMissing)

                of MessageType.SketchHashesRequest:
                    var requested: Block
                    try:
                        requested = manager.functions.merit.getBlockByHash(msg.message.toHash(256))
                        res = newMessage(MessageType.SketchHashes, requested.body.packets.len.toBinary(INT_LEN))
                        for packet in requested.body.packets:
                            res.message &= sketchHash(requested.header.sketchSalt, packet).toBinary(SKETCH_HASH_LEN)
                    except ValueError as e:
                        panic("Couln't convert a 32-byte message to a 32-byte hash: " & e.msg)
                    except IndexError:
                        res = newMessage(MessageType.DataMissing)

                of MessageType.SketchHashRequests:
                    var requested: Block
                    try:
                        requested = manager.functions.merit.getBlockByHash(msg.message[0 ..< HASH_LEN].toHash(256))

                        #Create a Table of the Sketch Hashes.
                        var packets: Table[string, VerificationPacket] = initTable[string, VerificationPacket]()
                        for packet in requested.body.packets:
                            packets[sketchHash(requested.header.sketchSalt, packet).toBinary(SKETCH_HASH_LEN)] = packet

                        for i in 0 ..< msg.message[HASH_LEN ..< HASH_LEN + INT_LEN].fromBinary():
                            res = newMessage(
                                MessageType.VerificationPacket,
                                packets[msg.message[
                                    HASH_LEN + INT_LEN + (i * SKETCH_HASH_LEN) ..<
                                    HASH_LEN + INT_LEN + SKETCH_HASH_LEN + (i * SKETCH_HASH_LEN)
                                ]].serialize()
                            )

                            try:
                                await peer.sendSync(res)
                            except SocketError:
                                return
                            except Exception as e:
                                panic("Failed to reply to a Sync request: " & e.msg)

                        res = newMessage(MessageType.End)
                    except ValueError as e:
                        panic("Couldn't convert a 32-byte message to a 32-byte hash: " & e.msg)
                    except IndexError, KeyError:
                        res = newMessage(MessageType.DataMissing)

                of MessageType.TransactionRequest:
                    var tx: Transaction
                    try:
                        tx = manager.functions.transactions.getTransaction(msg.message.toHash(256))
                        if tx of Mint:
                            raise newLoggedException(IndexError, "TransactionRequest asked for a Mint.")

                        var content: MessageType
                        case tx:
                            of Claim as _:
                                content = MessageType.Claim
                            of Send as _:
                                content = MessageType.Send
                            of Data as _:
                                content = MessageType.Data
                            else:
                                panic("Responding with an unsupported Transaction type to a TransactionRequest.")

                        res = newMessage(content, tx.serialize())
                    except ValueError as e:
                        panic("Couln't convert a 32-byte message to a 32-byte hash: " & e.msg)
                    except IndexError:
                        res = newMessage(MessageType.DataMissing)

                of MessageType.DataMissing:
                    try:
                        handleResponse[SyncRequest, void, bool](
                            manager,
                            peer,
                            msg,
                            proc (
                                serialization: string,
                                check: bool
                            ): void {.forceCheck: [].} =
                                panic("Handling a DataMissing got to the parse function.")
                        )
                    except PeerError:
                        peer.close()
                        return

                of MessageType.Claim:
                    try:
                        handleResponse[TransactionSyncRequest, Transaction, Hash[256]](
                            manager,
                            peer,
                            msg,
                            proc (
                                serialization: string,
                                check: Hash[256]
                            ): Transaction {.forceCheck: [
                                ValueError
                            ].} =
                                try:
                                    result = serialization.parseClaim()
                                except ValueError as e:
                                    raise e

                                if result.hash != check:
                                    raise newLoggedException(ValueError, "Peer sent the wrong Transaction.")
                        )
                    except ValueError as e:
                        panic("Passing a function which can raise ValueError raised a ValueError: " & e.msg)
                    except PeerError:
                        peer.close()
                        return

                of MessageType.Send:
                    try:
                        handleResponse[TransactionSyncRequest, Transaction, Hash[256]](
                            manager,
                            peer,
                            msg,
                            proc (
                                serialization: string,
                                check: Hash[256]
                            ): Transaction {.forceCheck: [
                                ValueError
                            ].} =
                                try:
                                    result = serialization.parseSend(uint32(0))
                                except ValueError as e:
                                    raise e
                                except Spam as e:
                                    panic("Synced Transaction was identified as Spam: " & e.msg)

                                if result.hash != check:
                                    raise newLoggedException(ValueError, "Peer sent the wrong Transaction.")
                        )
                    except ValueError as e:
                        panic("Passing a function which can raise ValueError raised a ValueError: " & e.msg)
                    except PeerError:
                        peer.close()
                        return

                of MessageType.Data:
                    try:
                        handleResponse[TransactionSyncRequest, Transaction, Hash[256]](
                            manager,
                            peer,
                            msg,
                            proc (
                                serialization: string,
                                check: Hash[256]
                            ): Transaction {.forceCheck: [
                                ValueError
                            ].} =
                                try:
                                    result = serialization.parseData(uint32(0))
                                except ValueError as e:
                                    raise e
                                except Spam as e:
                                    panic("Synced Transaction was identified as Spam: " & e.msg)

                                if result.hash != check:
                                    raise newLoggedException(ValueError, "Peer sent the wrong Transaction.")
                        )
                    except ValueError as e:
                        panic("Passing a function which can raise ValueError raised a ValueError: " & e.msg)
                    except PeerError:
                        peer.close()
                        return

                of MessageType.BlockHeader:
                    try:
                        handleResponse[BlockHeaderSyncRequest, BlockHeader, Hash[256]](
                            manager,
                            peer,
                            msg,
                            proc (
                                serialization: string,
                                check: Hash[256]
                            ): BlockHeader {.forceCheck: [
                                ValueError
                            ].} =
                                try:
                                    result = serialization.parseBlockHeader()
                                except ValueError as e:
                                    raise e

                                if result.hash != check:
                                    raise newLoggedException(ValueError, "Peer sent the wrong BlockHeader.")
                        )
                    except ValueError as e:
                        panic("Passing a function which can raise ValueError raised a ValueError: " & e.msg)
                    except PeerError:
                        peer.close()
                        return

                of MessageType.BlockBody:
                    try:
                        handleResponse[BlockBodySyncRequest, SketchyBlockBody, Hash[256]](
                            manager,
                            peer,
                            msg,
                            proc (
                                serialization: string,
                                check: Hash[256]
                            ): SketchyBlockBody {.forceCheck: [
                                ValueError
                            ].} =
                                try:
                                    result = serialization.parseBlockBody()
                                except ValueError as e:
                                    raise e

                                if (
                                    (result.data.elements.len == 0) and
                                    (result.data.packetsContents == Hash[256]())
                                ):
                                    if check == Hash[256]():
                                        return
                                    raise newLoggedException(ValueError, "Peer sent the wrong BlockBody.")

                                var elementsMerkle: Merkle = newMerkle()
                                for elem in result.data.elements:
                                    elementsMerkle.add(Blake256(elem.serializeContents()))

                                if Blake256(result.data.packetsContents.toString() & elementsMerkle.hash.toString()) != check:
                                    raise newLoggedException(ValueError, "Peer sent the wrong BlockBody.")
                        )
                    except ValueError as e:
                        panic("Passing a function which can raise ValueError raised a ValueError: " & e.msg)
                    except PeerError:
                        peer.close()
                        return

                of MessageType.SketchHashes:
                    try:
                        handleResponse[SketchHashesSyncRequest, seq[uint64], Hash[256]](
                            manager,
                            peer,
                            msg,
                            proc (
                                serialization: string,
                                check: Hash[256]
                            ): seq[uint64] {.forceCheck: [
                                ValueError
                            ].} =
                                #Parse out the sketch hashes.
                                result = newSeq[uint64](msg.message[0 ..< INT_LEN].fromBinary())
                                for i in 0 ..< result.len:
                                    result[i] = uint64(msg.message[INT_LEN + (i * SKETCH_HASH_LEN) ..< INT_LEN + SKETCH_HASH_LEN + (i * SKETCH_HASH_LEN)].fromBinary())

                                #Sort the result.
                                result.sort(SortOrder.Descending)

                                #Verify the sketchCheck Merkle.
                                try:
                                    check.verifySketchCheck(result)
                                except ValueError as e:
                                    raise e
                        )
                    except ValueError as e:
                        panic("Passing a function which can raise ValueError raised a ValueError: " & e.msg)
                    except PeerError:
                        peer.close()
                        return

                of MessageType.VerificationPacket:
                    #Verify there's a Sync Request to check.
                    if peer.requests.len == 0:
                        peer.close()
                        return

                    #Verify the Request is still active.
                    if not manager.requests.hasKey(peer.requests[0]):
                        peer.requests.delete(0)
                        break thisMsg

                    var request: SketchHashSyncRequests
                    try:
                        #Verify the Request is a SketchHashSyncRequests.
                        if not (manager.requests[peer.requests[0]] of SketchHashSyncRequests):
                            peer.close()
                            return

                        request = cast[SketchHashSyncRequests](manager.requests[peer.requests[0]])
                    except KeyError as e:
                        panic("Couldn't get a SyncRequest we confirmed we have: " & e.msg)

                    #Receive the rest of the packets.
                    var packets: seq[VerificationPacket] = newSeq[Verificationpacket](request.check.sketchHashes.len)

                    #Parse and verify the initial packet.
                    try:
                        packets[0] = msg.message.parseVerificationPacket()
                    except ValueError:
                        peer.close()
                        return
                    if sketchHash(request.check.salt, packets[0]) != request.check.sketchHashes[0]:
                        peer.close()
                        return

                    var i: int = 1
                    while i < packets.len:
                        try:
                            msg = await peer.recvSync()
                        except SocketError:
                            return
                        except PeerError:
                            peer.close()
                            return
                        except Exception as e:
                            panic("Receiving a new message threw an Exception despite catching all thrown Exceptions: " & e.msg)

                        if msg.content == MessageType.DataMissing:
                            break

                        #Parse and verify the packet.
                        try:
                            packets[i] = msg.message.parseVerificationPacket()
                        except ValueError:
                            peer.close()
                            return
                        if sketchHash(request.check.salt, packets[i]) != request.check.sketchHashes[i]:
                            peer.close()
                            return

                        #Increment i.
                        inc(i)

                    #Verify we received every packet.
                    if i != request.check.sketchHashes.len:
                        break thisMsg

                    #Complete the future, if it's still incomplete.
                    if not request.result.finished:
                        try:
                            request.result.complete(packets)
                        except Exception as e:
                            panic("Couldn't complete a Future: " & e.msg)

                    #Delete the Request.
                    manager.requests.del(peer.requests[0])
                    peer.requests.delete(0)

                else:
                    peer.close()
                    return

            #Reply with the response, if there is one.
            if res.content != MessageType.End:
                try:
                    await peer.sendSync(res)
                except SocketError:
                    return
                except Exception as e:
                    panic("Failed to reply to a Sync request: " & e.msg)

        #Receive the next message.
        try:
            msg = await peer.recvSync()
        except SocketError:
            return
        except PeerError:
            peer.close()
            return
        except Exception as e:
            panic("Receiving a new message threw an Exception despite catching all thrown Exceptions: " & e.msg)
