#Errors lib.
import ../lib/Errors

#Util lib.
import ../lib/Util

#Hash lib.
import ../lib/Hash

#Sketcher lib.
import ../lib/Sketcher

#Transactions lib (for all Transaction types).
import ../Database/Transactions/Transactions

#Element libs.
import ../Database/Consensus/Elements/Elements

#Block lib.
import ../Database/Merit/Block

#Serialization libs.
import Serialize/SerializeCommon

import Serialize/Merit/SerializeBlockHeader
import Serialize/Merit/SerializeBlockBody

import Serialize/Consensus/SerializeVerificationPacket

import Serialize/Transactions/SerializeClaim
import Serialize/Transactions/SerializeSend
import Serialize/Transactions/SerializeData

#Message object.
import objects/MessageObj

#Peer lib and Peers object.
import Peer
import objects/PeersObj

#Export Peer/PeersObj.
export Peer
export PeersObj

#Network Function Box.
import objects/NetworkLibFunctionBoxObj

#Math standard lib.
import math

#Random standard lib.
import random

#Networking standard libs.
import asyncdispatch, asyncnet

#Sets standard lib.
import sets

#Table standard lib.
import tables

#String utils standard lib.
import strutils

#Handle a Peer.
proc handle(
    peer: Peer,
    networkFunctions: NetworkLibFunctionBox,
    tail: Hash[256]
) {.forceCheck: [
    PeerError
], async.} =
    try:
        #Simulate a BlockchainTail message to trigger syncing from a newly handshaked Peer.
        try:
            await networkFunctions.handle(newMessage(
                peer.id,
                MessageType.BlockchainTail,
                32,
                tail.toString()
            ))
        except Spam:
            doAssert(false, "Artificial BlockchainTail message threw a Spam exception.")

        #Message loop variable.
        var msg: Message

        #While the Peer is still connected...
        while not peer.isClosed():
            #Read in a new message.
            msg = await peer.recv()

            #If this was a message changing the sync state, update it and continue.
            if msg.content == MessageType.Syncing:
                peer.remoteSync = true

                #Send SyncingAcknowledged.
                await peer.send(newMessage(MessageType.SyncingAcknowledged))

                #Handle the syncing messages.
                while (not peer.isClosed()) and peer.remoteSync:
                    #Read in a new message.
                    msg = await peer.recv()

                    #Switch based off the message type.
                    case msg.content:
                        of MessageType.Handshake:
                            await peer.send(newMessage(MessageType.BlockchainTail, networkFunctions.getTail().toString()))

                        of MessageType.PeersRequest:
                            var
                                #Peers we have yet to send.
                                usable: seq[Peer] = networkFunctions.getPeers()
                                #Peers we want to send.
                                peers: int = min(8, usable.len)
                                #Result to send back.
                                res: string

                            while peers > 0:
                                if rand(high(usable)) < peers:
                                    #Skip Peers who aren't servers.
                                    if not usable[0].server:
                                        usable.del(0)
                                        if peers > usable.len:
                                            dec(peers)
                                        continue

                                    #Skip the Peer who sent us this message.
                                    if usable[0].id == msg.peer:
                                        usable.del(0)
                                        if peers > usable.len:
                                            dec(peers)
                                        continue

                                    #Append the peer.
                                    res &= usable[0].ip & usable[0].port.toBinary(PORT_LEN)
                                    dec(peers)

                                #Delete this Peer from usable.
                                usable.del(0)

                            #Send the peers.
                            await peer.send(newMessage(MessageType.Peers, char(res.len div (IP_LEN + PORT_LEN)) & res))

                        of MessageType.BlockListRequest:
                            var
                                res: string = ""
                                last: Hash[256] = msg.message[BYTE_LEN + BYTE_LEN ..< BYTE_LEN + BYTE_LEN +  HASH_LEN].toHash(256)
                                i: int = -1

                            try:
                                #Backwards.
                                if int(msg.message[0]) == 0:
                                    while i < int(msg.message[1]):
                                        last = networkFunctions.getBlockHashBefore(last)
                                        res &= last.toString()
                                        inc(i)
                                #Forwards.
                                elif int(msg.message[0]) == 1:
                                    while i < int(msg.message[1]):
                                        last = networkFunctions.getBlockHashAfter(last)
                                        res &= last.toString()
                                        inc(i)
                                else:
                                    raise newException(PeerError, "Peer requested an invalid direction for their BlockList.")
                            except IndexError:
                                discard

                            if i == -1:
                                await peer.send(newMessage(MessageType.DataMissing))
                            else:
                                await peer.send(newMessage(MessageType.BlockList, char(i) & res))

                        of MessageType.BlockHeaderRequest:
                            var header: BlockHeader
                            try:
                                header = networkFunctions.getBlock(msg.message.toHash(256)).header
                            except ValueError as e:
                                doAssert(false, "Couln't convert a 32-byte message to a 32-byte hash: " & e.msg)
                            except IndexError:
                                await peer.send(newMessage(MessageType.DataMissing))
                                continue

                            await peer.send(newMessage(MessageType.BlockHeader, header.serialize()))

                        of MessageType.BlockBodyRequest:
                            var requested: Block
                            try:
                                requested = networkFunctions.getBlock(msg.message.toHash(256))
                            except ValueError as e:
                                doAssert(false, "Couln't convert a 32-byte message to a 32-byte hash: " & e.msg)
                            except IndexError:
                                await peer.send(newMessage(MessageType.DataMissing))
                                continue

                            await peer.send(newMessage(MessageType.BlockBody, requested.body.serialize(requested.header.sketchSalt)))

                        of MessageType.SketchHashesRequest:
                            var requested: Block
                            try:
                                requested = networkFunctions.getBlock(msg.message.toHash(256))
                            except ValueError as e:
                                doAssert(false, "Couln't convert a 32-byte message to a 32-byte hash: " & e.msg)
                            except IndexError:
                                await peer.send(newMessage(MessageType.DataMissing))
                                continue

                            var res: string = requested.body.packets.len.toBinary(INT_LEN)
                            for packet in requested.body.packets:
                                res &= sketchHash(requested.header.sketchSalt, packet).toBinary(SKETCH_HASH_LEN)
                            await peer.send(newMessage(MessageType.SketchHashes, res))

                        of MessageType.SketchHashRequests:
                            var requested: Block
                            try:
                                requested = networkFunctions.getBlock(msg.message[0 ..< HASH_LEN].toHash(256))
                            except ValueError as e:
                                doAssert(false, "Couln't convert a 32-byte message to a 32-byte hash: " & e.msg)
                            except IndexError:
                                await peer.send(newMessage(MessageType.DataMissing))
                                continue

                            #Create a Table of the Sketch Hashes.
                            var packets: Table[string, VerificationPacket] = initTable[string, VerificationPacket]()
                            for packet in requested.body.packets:
                                packets[sketchHash(requested.header.sketchSalt, packet).toBinary(SKETCH_HASH_LEN)] = packet

                            try:
                                for i in 0 ..< msg.message[HASH_LEN ..< HASH_LEN + INT_LEN].fromBinary():
                                    await peer.send(newMessage(
                                        MessageType.VerificationPacket,
                                        packets[msg.message[
                                            HASH_LEN + INT_LEN + (i * SKETCH_HASH_LEN) ..<
                                            HASH_LEN + INT_LEN + SKETCH_HASH_LEN + (i * SKETCH_HASH_LEN)
                                        ]].serialize()
                                    ))
                            except KeyError:
                                await peer.send(newMessage(MessageType.DataMissing))

                        of MessageType.TransactionRequest:
                            var tx: Transaction
                            try:
                                tx = networkFunctions.getTransaction(msg.message.toHash(256))
                                if tx of Mint:
                                    raise newException(IndexError, "TransactionRequest asked for a Mint.")
                            except ValueError as e:
                                doAssert(false, "Couln't convert a 32-byte message to a 32-byte hash: " & e.msg)
                            except IndexError:
                                await peer.send(newMessage(MessageType.DataMissing))
                                continue

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

                            await peer.send(newMessage(content, tx.serialize()))

                        of MessageType.SyncingOver:
                            peer.remoteSync = false

                        else:
                            raise newException(PeerError, "Peer sent a message which can't be sent during syncing during syncing.")
            else:
                #Handle our new message.
                try:
                    await networkFunctions.handle(msg)
                except Spam:
                    continue
    except PeerError as e:
        raise e
    except Exception as e:
        doAssert(false, "Receiving/sending/handling a message threw an Exception despite catching all thrown Exceptions: " & e.msg)

#Add a new Peer from a Socket.
proc add*(
    peers: Peers,
    server: bool,
    port: int,
    socket: AsyncSocket,
    networkFunctions: NetworkLibFunctionBox
) {.forceCheck: [], async.} =
    #Get the IP.
    var
        address: string
        addressParts: seq[string]
    try:
        address = socket.getPeerAddr()[0]

        if (socket.getLocalAddr()[0] == address) and (address != "127.0.0.1"):
            try:
                socket.close()
            except Exception as e:
                doAssert(false, "Failed to close a socket: " & e.msg)
            return

        addressParts = address.split(".")
    except OSError as e:
        doAssert(false, "Failed to get a peer's address: " & e.msg)

    var ip: string
    try:
        ip = (
            char(parseInt(addressParts[0])) &
            char(parseInt(addressParts[1])) &
            char(parseInt(addressParts[2])) &
            char(parseInt(addressParts[3]))
        )
    except ValueError as e:
        doAssert(false, "IP contained an invalid integer: " & e.msg)

    if not networkFunctions.allowRepeatConnections():
        #If the Peer is already connected, close the socket and return.
        if peers.connected.contains(ip):
            try:
                socket.close()
            except Exception as e:
                doAssert(false, "Failed to close a socket: " & e.msg)
            return

    #Create the Peer.
    var peer: Peer = newPeer(
        ip,
        peers.count,
        socket
    )
    #Increase the count so the next Peer has an unique ID.
    inc(peers.count)

    #Handshake with the Peer.
    var tail: Hash[256]
    try:
        tail = await peer.handshake(
            networkFunctions.getNetworkID(),
            networkFunctions.getProtocol(),
            server,
            port,
            networkFunctions.getTail()
        )
    except PeerError:
        peer.close()
        return
    except Exception as e:
        doAssert(false, "Handshaking threw an Exception despite catching all thrown Exceptions: " & e.msg)

    #Add the new Peer to Peers.
    peers.add(peer)

    #Handle it.
    try:
        await peer.handle(networkFunctions, tail)
    #If an IndexError happened, we couldn't get the Peer to reply to them.
    #This means something else disconnected and removed them.
    except IndexError:
        #Disconnect them again to be safe.
        peers.disconnect(peer.id)
    except PeerError:
        peers.disconnect(peer.id)
    except Exception as e:
        doAssert(false, "Handling a Peer threw an Exception despite catching all thrown Exceptions: " & e.msg)

#Reply to a message.
proc reply*(
    peers: Peers,
    msg: Message,
    res: Message
) {.forceCheck: [
    IndexError
], async.} =
    #Get the Peer.
    var peer: Peer
    try:
        peer = peers[msg.peer]
    except IndexError as e:
        raise e

    #Try to send the message.
    try:
        await peer.send(res)
    #If that failed, disconnect the Peer.
    except PeerError:
        peers.disconnect(peer.id)
    except Exception as e:
        doAssert(false, "Replying to a message threw an Exception despite catching all thrown Exceptions: " & e.msg)

#Broadcast a message to our Peers.
proc broadcast*(
    peers: Peers,
    msg: Message
) {.forceCheck: [], async.} =
    if peers.peers.len == 0:
        return

    var
        #Peers we need to broadcast to.
        req: int = max(
            min(peers.peers.len, 3),
            int(ceil(sqrt(float(peers.peers.len))))
        )
        #Peers we have yet to handle.
        usable: seq[Peer] = peers.peers

    while req > 0:
        if usable[0].remoteSync or (usable[0].syncLevels != 0):
            usable.del(0)
            if req > usable.len:
                dec(req)
            continue

        if rand(high(usable)) < req:
            #Skip the Peer who sent us this message.
            if usable[0].id == msg.peer:
                usable.del(0)
                if req > usable.len:
                    dec(req)
                continue

            #Try to send the message.
            try:
                await usable[0].send(msg)
                dec(req)
            #If that failed, mark the Peer for disconnection.
            except PeerError:
                peers.disconnect(usable[0].id)
            except Exception as e:
                doAssert(false, "Broadcasting a message to a Peer threw an Exception despite catching all thrown Exceptions: " & e.msg)

        #Delete this Peer from usable.
        usable.del(0)
