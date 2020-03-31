#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#BlockHeader object.
import ../../Database/Merit/objects/BlockHeaderObj

#Elements lib.
import ../../Database/Consensus/Elements/Elements

#Transaction lib.
import ../../Database/Transactions/Transaction

#GlobalFunctionBox object.
import ../../objects/GlobalFunctionBoxObj

#Message object.
import MessageObj

#Peer lib.
import ../Peer as PeerFile

#SerializeCommon lib.
import ../Serialize/SerializeCommon

#Parse libs.
import ../Serialize/Merit/ParseBlockHeader

import ../Serialize/Consensus/ParseVerification
import ../Serialize/Consensus/ParseSendDifficulty
import ../Serialize/Consensus/ParseDataDifficulty
import ../Serialize/Consensus/ParseMeritRemoval

import ../Serialize/Transactions/ParseClaim
import ../Serialize/Transactions/ParseSend
import ../Serialize/Transactions/ParseData

#Chronos external lib.
import chronos

#Tables standard lib.
import tables

#LiveManager object.
type LiveManager* = ref object
    #Protocol version.
    protocol*: int
    #Network ID.
    network*: int
    #Services byte.
    services*: char
    #Server port.
    port*: int

    #Table of every Peer.
    peers: TableRef[int, Peer]

    #Global Function Box.
    functions*: GlobalFunctionBox

#Constructor.
func newLiveManager*(
    protocol: int,
    network: int,
    port: int,
    peers: TableRef[int, Peer],
    functions: GlobalFunctionBox
): LiveManager {.forceCheck: [].} =
    LiveManager(
        protocol: protocol,
        network: network,
        port: port,

        peers: peers,

        functions: functions
    )

#Update the services byte.
func updateServices*(
    manager: LiveManager,
    service: uint8
) {.forceCheck: [].} =
    manager.services = char(uint8(manager.services) or service)

#Handle a new connection.
proc handle*(
    manager: LiveManager,
    peer: Peer,
    handshake: Message = newMessage(MessageType.End)
) {.forceCheck: [], async.} =
    #Send our Handshake and get their Handshake.
    try:
        await peer.sendLive(newMessage(
            MessageType.Handshake,
            char(manager.protocol) &
            char(manager.network) &
            manager.services &
            manager.port.toBinary(PORT_LEN) &
            manager.functions.merit.getTail().toString()
        ))
    except SocketError:
        return
    except Exception as e:
        panic("Handshaking threw an Exception despite catching all thrown Exceptions: " & e.msg)

    var msg: Message = handshake
    if msg.content == MessageType.End:
        try:
            msg = await peer.recvLive()
        except SocketError:
            return
        except PeerError:
            peer.close()
            return
        except Exception as e:
            panic("Handshaking threw an Exception despite catching all thrown Exceptions: " & e.msg)

    if msg.content != MessageType.Handshake:
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

    #We don't bother with the initial tail as we do that for the Sync socket.

    #Receive and handle messages forever.
    while true:
        try:
            msg = await peer.recvLive()
        except SocketError:
            return
        except PeerError:
            peer.close()
            return
        except Exception as e:
            panic("Receiving a new message threw an Exception despite catching all thrown Exceptions: " & e.msg)

        try:
            case msg.content:
                of MessageType.Handshake:
                    try:
                        await peer.sendLive(
                            newMessage(
                                MessageType.BlockchainTail,
                                manager.functions.merit.getTail().toString()
                            )
                        )
                    except SocketError:
                        return
                    except Exception as e:
                        panic("Replying `BlockchainTail` in response to a keep-alive `Handshake` threw an Exception despite catching all thrown Exceptions: " & e.msg)

                    #Add the tail.
                    var tail: Hash[256]
                    try:
                        tail = msg.message[5 ..< 37].toHash(256)
                    except ValueError as e:
                        panic("Couldn't create a 32-byte hash out of a 32-byte value: " & e.msg)

                    try:
                        await manager.functions.merit.addBlockByHash(peer, tail)
                    except Exception as e:
                        panic("Adding a Block threw an Exception despite catching all thrown Exceptions: " & e.msg)

                of MessageType.BlockchainTail:
                    #Get the hash.
                    var tail: Hash[256]
                    try:
                        tail = msg.message[0 ..< 32].toHash(256)
                    except ValueError as e:
                        panic("Couldn't turn a 32-byte string into a 32-byte hash: " & e.msg)

                    #Add the Block.
                    try:
                        await manager.functions.merit.addBlockByHash(peer, tail)
                    except Exception as e:
                        panic("Adding a Block threw an Exception despite catching all thrown Exceptions: " & e.msg)

                of MessageType.Claim:
                    var claim: Claim = msg.message.parseClaim()
                    manager.functions.transactions.addClaim(claim)

                of MessageType.Send:
                    var send: Send = msg.message.parseSend(manager.functions.consensus.getSendDifficulty())
                    manager.functions.transactions.addSend(send)

                of MessageType.Data:
                    var data: Data = msg.message.parseData(manager.functions.consensus.getDataDifficulty())
                    manager.functions.transactions.addData(data)

                of MessageType.SignedVerification:
                    var verif: SignedVerification = msg.message.parseSignedVerification()
                    manager.functions.consensus.addSignedVerification(verif)

                of MessageType.SignedSendDifficulty:
                    var sendDiff: SignedSendDifficulty = msg.message.parseSignedSendDifficulty()
                    manager.functions.consensus.addSignedSendDifficulty(sendDiff)

                of MessageType.SignedDataDifficulty:
                    var dataDiff: SignedDataDifficulty = msg.message.parseSignedDataDifficulty()
                    manager.functions.consensus.addSignedDataDifficulty(dataDiff)

                of MessageType.SignedMeritRemoval:
                    var mr: SignedMeritRemoval = msg.message.parseSignedMeritRemoval()

                    try:
                        await manager.functions.consensus.addSignedMeritRemoval(mr)
                    except ValueError:
                        peer.close()
                        return
                    except DataExists:
                        continue
                    except Exception as e:
                        panic("Adding a SignedMeritRemoval threw an Exception despite catching all thrown Exceptions: " & e.msg)

                of MessageType.BlockHeader:
                    var header: BlockHeader = manager.functions.merit.getRandomX().parseBlockHeader(msg.message)

                    try:
                        await manager.functions.merit.addBlockByHeader(header, false)
                    except ValueError, DataMissing:
                        peer.close()
                        return
                    except DataExists:
                        continue
                    except Exception as e:
                        panic("Adding a Block threw an Exception despite catching all thrown Exceptions: " & e.msg)

                else:
                    peer.close()
                    return
        except ValueError, DataMissing:
            peer.close()
            return
        except Spam, DataExists:
            continue
