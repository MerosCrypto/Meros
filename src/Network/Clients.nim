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

#Client lib and Clients object.
import Client
import objects/ClientsObj

#Export Client/ClientsObj.
export Client
export ClientsObj

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

#Handle a client.
proc handle(
    client: Client,
    networkFunctions: NetworkLibFunctionBox,
    tail: Hash[256]
) {.forceCheck: [
    ClientError
], async.} =
    try:
        #Simulate a BlockchainTail message to trigger syncing from a newly handshaked client.
        try:
            await networkFunctions.handle(newMessage(
                client.id,
                MessageType.BlockchainTail,
                32,
                tail.toString()
            ))
        except Spam:
            doAssert(false, "Artificial BlockchainTail message threw a Spam exception.")

        #Message loop variable.
        var msg: Message

        #While the client is still connected...
        while not client.isClosed():
            #Read in a new message.
            msg = await client.recv()

            #If this was a message changing the sync state, update it and continue.
            if msg.content == MessageType.Syncing:
                client.remoteSync = true

                #Send SyncingAcknowledged.
                await client.send(newMessage(MessageType.SyncingAcknowledged))

                #Handle the syncing messages.
                while (not client.isClosed()) and client.remoteSync:
                    #Read in a new message.
                    msg = await client.recv()

                    #Switch based off the message type.
                    case msg.content:
                        of MessageType.Handshake:
                            await client.send(newMessage(MessageType.BlockchainTail, networkFunctions.getTail().toString()))

                        of MessageType.PeersRequest:
                            var
                                #Clients we have yet to send.
                                usable: seq[Client] = networkFunctions.getClients()
                                #Peers we want to send.
                                peers: int = min(8, usable.len)
                                #Result to send back.
                                res: string

                            while peers > 0:
                                if rand(high(usable)) < peers:
                                    #Skip Clients who aren't servers.
                                    if not usable[0].server:
                                        usable.del(0)
                                        if peers > usable.len:
                                            dec(peers)
                                        continue

                                    #Skip the Client who sent us this message.
                                    if usable[0].id == msg.client:
                                        usable.del(0)
                                        if peers > usable.len:
                                            dec(peers)
                                        continue

                                    #Append the peer.
                                    res &= usable[0].ip & usable[0].port.toBinary(PORT_LEN)
                                    dec(peers)

                                #Delete this Client from usable.
                                usable.del(0)

                            #Send the peers.
                            await client.send(newMessage(MessageType.Peers, char(res.len div (IP_LEN + PORT_LEN)) & res))

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
                                    raise newException(ClientError, "Client requested an invalid direction for their BlockList.")
                            except IndexError:
                                discard

                            if i == -1:
                                await client.send(newMessage(MessageType.DataMissing))
                            else:
                                await client.send(newMessage(MessageType.BlockList, char(i) & res))

                        of MessageType.BlockHeaderRequest:
                            var header: BlockHeader
                            try:
                                header = networkFunctions.getBlock(msg.message.toHash(256)).header
                            except ValueError as e:
                                doAssert(false, "Couln't convert a 32-byte message to a 32-byte hash: " & e.msg)
                            except IndexError:
                                await client.send(newMessage(MessageType.DataMissing))
                                continue

                            await client.send(newMessage(MessageType.BlockHeader, header.serialize()))

                        of MessageType.BlockBodyRequest:
                            var requested: Block
                            try:
                                requested = networkFunctions.getBlock(msg.message.toHash(256))
                            except ValueError as e:
                                doAssert(false, "Couln't convert a 32-byte message to a 32-byte hash: " & e.msg)
                            except IndexError:
                                await client.send(newMessage(MessageType.DataMissing))
                                continue

                            await client.send(newMessage(MessageType.BlockBody, requested.body.serialize(requested.header.sketchSalt)))

                        of MessageType.SketchHashesRequest:
                            var requested: Block
                            try:
                                requested = networkFunctions.getBlock(msg.message.toHash(256))
                            except ValueError as e:
                                doAssert(false, "Couln't convert a 32-byte message to a 32-byte hash: " & e.msg)
                            except IndexError:
                                await client.send(newMessage(MessageType.DataMissing))
                                continue

                            var res: string = requested.body.packets.len.toBinary(INT_LEN)
                            for packet in requested.body.packets:
                                res &= sketchHash(requested.header.sketchSalt, packet).toBinary(SKETCH_HASH_LEN)
                            await client.send(newMessage(MessageType.SketchHashes, res))

                        of MessageType.SketchHashRequests:
                            var requested: Block
                            try:
                                requested = networkFunctions.getBlock(msg.message[0 ..< HASH_LEN].toHash(256))
                            except ValueError as e:
                                doAssert(false, "Couln't convert a 32-byte message to a 32-byte hash: " & e.msg)
                            except IndexError:
                                await client.send(newMessage(MessageType.DataMissing))
                                continue

                            #Create a Table of the Sketch Hashes.
                            var packets: Table[string, VerificationPacket] = initTable[string, VerificationPacket]()
                            for packet in requested.body.packets:
                                packets[sketchHash(requested.header.sketchSalt, packet).toBinary(SKETCH_HASH_LEN)] = packet

                            try:
                                for i in 0 ..< msg.message[HASH_LEN ..< HASH_LEN + INT_LEN].fromBinary():
                                    await client.send(newMessage(
                                        MessageType.VerificationPacket,
                                        packets[msg.message[
                                            HASH_LEN + INT_LEN + (i * SKETCH_HASH_LEN) ..<
                                            HASH_LEN + INT_LEN + SKETCH_HASH_LEN + (i * SKETCH_HASH_LEN)
                                        ]].serialize()
                                    ))
                            except KeyError:
                                await client.send(newMessage(MessageType.DataMissing))

                        of MessageType.TransactionRequest:
                            var tx: Transaction
                            try:
                                tx = networkFunctions.getTransaction(msg.message.toHash(256))
                                if tx of Mint:
                                    raise newException(IndexError, "TransactionRequest asked for a Mint.")
                            except ValueError as e:
                                doAssert(false, "Couln't convert a 32-byte message to a 32-byte hash: " & e.msg)
                            except IndexError:
                                await client.send(newMessage(MessageType.DataMissing))
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

                            await client.send(newMessage(content, tx.serialize()))

                        of MessageType.SyncingOver:
                            client.remoteSync = false

                        else:
                            raise newException(ClientError, "Client sent a message which can't be sent during syncing during syncing.")
            else:
                #Handle our new message.
                try:
                    await networkFunctions.handle(msg)
                except Spam:
                    continue
    except ClientError as e:
        raise e
    except Exception as e:
        doAssert(false, "Receiving/sending/handling a message threw an Exception despite catching all thrown Exceptions: " & e.msg)

#Add a new Client from a Socket.
proc add*(
    clients: Clients,
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
        #If the Client is already connected, close the socket and return.
        if clients.connected.contains(ip):
            try:
                socket.close()
            except Exception as e:
                doAssert(false, "Failed to close a socket: " & e.msg)
            return

    #Create the Client.
    var client: Client = newClient(
        ip,
        clients.count,
        socket
    )
    #Increase the count so the next client has an unique ID.
    inc(clients.count)

    #Handshake with the Client.
    var tail: Hash[256]
    try:
        tail = await client.handshake(
            networkFunctions.getNetworkID(),
            networkFunctions.getProtocol(),
            server,
            port,
            networkFunctions.getTail()
        )
    except ClientError:
        client.close()
        return
    except Exception as e:
        doAssert(false, "Handshaking threw an Exception despite catching all thrown Exceptions: " & e.msg)

    #Add the new Client to Clients.
    clients.add(client)

    #Handle it.
    try:
        await client.handle(networkFunctions, tail)
    #If an IndexError happened, we couldn't get the Client to reply to them.
    #This means something else disconnected and removed them.
    except IndexError:
        #Disconnect them again to be safe.
        clients.disconnect(client.id)
    except ClientError:
        clients.disconnect(client.id)
    except Exception as e:
        doAssert(false, "Handling a Client threw an Exception despite catching all thrown Exceptions: " & e.msg)

#Reply to a message.
proc reply*(
    clients: Clients,
    msg: Message,
    res: Message
) {.forceCheck: [
    IndexError
], async.} =
    #Get the client.
    var client: Client
    try:
        client = clients[msg.client]
    except IndexError as e:
        raise e

    #Try to send the message.
    try:
        await client.send(res)
    #If that failed, disconnect the client.
    except ClientError:
        clients.disconnect(client.id)
    except Exception as e:
        doAssert(false, "Replying to a message threw an Exception despite catching all thrown Exceptions: " & e.msg)

#Broadcast a message to all clients.
proc broadcast*(
    clients: Clients,
    msg: Message
) {.forceCheck: [], async.} =
    if clients.clients.len == 0:
        return

    var
        #Clients we need to broadcast to.
        req: int = max(
            min(clients.clients.len, 3),
            int(ceil(sqrt(float(clients.clients.len))))
        )
        #Clients we have yet to handle.
        usable: seq[Client] = clients.clients

    while req > 0:
        if usable[0].remoteSync or (usable[0].syncLevels != 0):
            usable.del(0)
            if req > usable.len:
                dec(req)
            continue

        if rand(high(usable)) < req:
            #Skip the Client who sent us this message.
            if usable[0].id == msg.client:
                usable.del(0)
                if req > usable.len:
                    dec(req)
                continue

            #Try to send the message.
            try:
                await usable[0].send(msg)
                dec(req)
            #If that failed, mark the Client for disconnection.
            except ClientError:
                clients.disconnect(usable[0].id)
            except Exception as e:
                doAssert(false, "Broadcasting a message to a Client threw an Exception despite catching all thrown Exceptions: " & e.msg)

        #Delete this Client from usable.
        usable.del(0)
