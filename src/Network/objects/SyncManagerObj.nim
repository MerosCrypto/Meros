#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#Sketcher lib.
import ../../lib/Sketcher

#Block object.
import ../../Database/Merit/objects/BlockObj

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

import ../Serialize/Transactions/ParseClaim
import ../Serialize/Transactions/ParseSend
import ../Serialize/Transactions/ParseData

#Async standard lib.
import asyncdispatch

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

        peers: peers,
        requests: initTable[int, SyncRequest](),

        functions: functions
    )

#Update the services byte.
func updateServices*(
    manager: SyncManager,
    service: uint8
) {.forceCheck: [].} =
    manager.services = char(uint8(manager.services) and service)

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
    except PeerError:
        peer.close()
        return
    except Exception as e:
        doAssert(false, "Handshaking threw an Exception despite catching all thrown Exceptions: " & e.msg)

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

    var tail: Hash[256]
    try:
        tail = msg.message[5 ..< 37].toHash(256)
    except ValueError as e:
        doAssert(false, "Couldn't create a 32-byte hash from a 32-byte value: " & e.msg)

    #Add the tail.
    try:
        await manager.functions.merit.addBlockByHash(tail, true)
    except ValueError, DataMissing:
        peer.close()
        return
    except DataExists, NotConnected:
        discard
    except Exception as e:
        doAssert(false, "Adding a Block threw an Exception despite catching all thrown Exceptions: " & e.msg)

    #Receive and handle messages forever.
    var res: Message
    while true:
        try:
            msg = await peer.recvSync()
        except PeerError:
            peer.close()
            return
        except Exception as e:
            doAssert(false, "Receiving a new message threw an Exception despite catching all thrown Exceptions: " & e.msg)

        res = newMessage(MessageType.End)

        case msg.content:
            of MessageType.Syncing:
                res = newMessage(
                    MessageType.BlockchainTail,
                    manager.functions.merit.getTail().toString()
                )

                #Add the tail.
                try:
                    tail = msg.message[5 ..< 37].toHash(256)
                except ValueError as e:
                    doAssert(false, "Couldn't create a 32-byte hash out of a 32-byte value: " & e.msg)
                try:
                    await manager.functions.merit.addBlockByHash(tail, true)
                except ValueError, DataMissing:
                    peer.close()
                    return
                except DataExists, NotConnected:
                    discard
                except Exception as e:
                    doAssert(false, "Adding a Block threw an Exception despite catching all thrown Exceptions: " & e.msg)

            of MessageType.BlockchainTail:
                #Get the tail.
                var tail: Hash[256]
                try:
                    tail = msg.message[0 ..< 32].toHash(256)
                except ValueError as e:
                    doAssert(false, "Couldn't turn a 32-byte string into a 32-byte hash: " & e.msg)

                #Add the Block.
                try:
                    await manager.functions.merit.addBlockByHash(tail, true)
                except ValueError, DataMissing:
                    peer.close()
                    return
                except DataExists, NotConnected:
                    discard
                except Exception as e:
                    doAssert(false, "Adding a Block threw an Exception despite catching all thrown Exceptions: " & e.msg)

            of MessageType.PeersRequest:
                doAssert(false)

            of MessageType.Peers:
                doAssert(false)

            of MessageType.BlockListRequest:
                var
                    list: string = ""
                    last: Hash[256]
                    i: int = -1

                try:
                    last = msg.message[BYTE_LEN + BYTE_LEN ..< BYTE_LEN + BYTE_LEN + HASH_LEN].toHash(256)
                except ValueError as e:
                    doAssert(false, "Couldn't create a 32-byte hash out of a 32-byte value: " & e.msg)

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
                doAssert(false)

            of MessageType.BlockHeaderRequest:
                try:
                    res = newMessage(
                        MessageType.BlockHeader,
                        manager.functions.merit.getBlockByHash(msg.message.toHash(256)).header.serialize()
                    )
                except ValueError as e:
                    doAssert(false, "Couln't convert a 32-byte message to a 32-byte hash: " & e.msg)
                except IndexError:
                    res = newMessage(MessageType.DataMissing)

            of MessageType.BlockBodyRequest:
                try:
                    var requested: Block = manager.functions.merit.getBlockByHash(msg.message.toHash(256))
                    res = newMessage(MessageType.BlockBody, requested.body.serialize(requested.header.sketchSalt))
                except ValueError as e:
                    doAssert(false, "Couln't convert a 32-byte message to a 32-byte hash: " & e.msg)
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
                    doAssert(false, "Couln't convert a 32-byte message to a 32-byte hash: " & e.msg)
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
                        except Exception as e:
                            doAssert(false, "Failed to reply to a Sync request: " & e.msg)
                except ValueError as e:
                    doAssert(false, "Couldn't convert a 32-byte message to a 32-byte hash: " & e.msg)
                except IndexError, KeyError:
                    res = newMessage(MessageType.DataMissing)

            of MessageType.TransactionRequest:
                var tx: Transaction
                try:
                    tx = manager.functions.transactions.getTransaction(msg.message.toHash(256))
                    if tx of Mint:
                        raise newException(IndexError, "TransactionRequest asked for a Mint.")

                    var content: MessageType
                    case tx:
                        of Claim as _:
                            content = MessageType.Claim
                        of Send as _:
                            content = MessageType.Send
                        of Data as _:
                            content = MessageType.Data
                        else:
                            doAssert(false, "Responding with an unsupported Transaction type to a TransactionRequest.")

                    res = newMessage(content, tx.serialize())
                except ValueError as e:
                    doAssert(false, "Couln't convert a 32-byte message to a 32-byte hash: " & e.msg)
                except IndexError:
                    res = newMessage(MessageType.DataMissing)

            of MessageType.DataMissing:
                doAssert(false)

            of MessageType.Claim:
                #Verify there's a Sync Request to check.
                if peer.requests.len == 0:
                    peer.close()
                    return

                #Verify the Request is still active.
                if not manager.requests.hasKey(peer.requests[0]):
                    peer.requests.delete(0)
                    continue

                try:
                    #Verify it's for a Transaction.
                    if not (manager.requests[peer.requests[0]] of TransactionSyncRequest):
                        peer.close()
                        return

                    #Complete the future.
                    var request: TransactionSyncRequest = cast[TransactionSyncRequest](manager.requests[peer.requests[0]])
                    try:
                        request.result.complete(msg.message.parseClaim())
                    except ValueError:
                        peer.close()
                        return
                    except Exception as e:
                        doAssert(false, "Couldn't complete a Future: " & e.msg)
                except KeyError as e:
                    doAssert(false, "Couldn't get a SyncRequest we confirmed we have: " & e.msg)

                #Delete the Request.
                manager.requests.del(peer.requests[0])
                peer.requests.delete(0)

            of MessageType.Send:
                doAssert(false)

            of MessageType.Data:
                doAssert(false)

            of MessageType.BlockHeader:
                doAssert(false)

            of MessageType.BlockBody:
                doAssert(false)

            of MessageType.SketchHashes:
                doAssert(false)

            of MessageType.VerificationPacket:
                doAssert(false)

            else:
                peer.close()
                return

        #Reply with the response, if there is one.
        if res.content != MessageType.End:
            try:
                await peer.sendSync(res)
            except Exception as e:
                doAssert(false, "Failed to reply to a Sync request: " & e.msg)
