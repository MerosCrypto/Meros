#Errors lib.
import ../lib/Errors

#Util lib.
import ../lib/Util

#Hash lib.
import ../lib/Hash

#Merit lib.
import ../Database/Merit/Merit

#Latice lib.
import ../Database/Lattice/Lattice

#Serialization libs.
import Serialize/SerializeCommon
import Serialize/Merit/SerializeBlock
import Serialize/Lattice/SerializeEntry

#Parsing libs.
import Serialize/Merit/ParseVerifications
import Serialize/Merit/ParseBlock
import Serialize/Lattice/ParseClaim
import Serialize/Lattice/ParseSend
import Serialize/Lattice/ParseReceive
import Serialize/Lattice/ParseData

#Message/Client/Clients/Network objects.
import objects/MessageObj
import objects/ClientObj
import objects/ClientsObj
import objects/NetworkObj
#Export the Message, Clients, and Network objects.
export MessageObj
export ClientsObj
export NetworkObj
#Export the Client to Socket converter.
export ClientObj.toSocket

#Socket sublibs.
import Server
import Clients
#Export the sync function.
export Clients.sync

#Events lib.
import ec_events

#Networking standard libs.
import asyncnet, asyncdispatch

#String utils standard lib.
import strutils

#Tables standard lib.
import tables

#Constructor.
proc newNetwork*(
    id: uint,
    protocol: uint,
    nodeEvents: EventEmitter
): Network {.raises: [AsyncError, SocketError].} =
    var
        #Event emitter for the socket sublibraries.
        subEvents: EventEmitter = newEventEmitter()
        #Socket for the server.
        server: AsyncSocket

    try:
        server = newAsyncSocket()
    except:
        raise newException(SocketError, "Couldn't create the Network's server socket.")

    #Create the Network object.
    var network: Network = newNetworkObj(
        id,
        protocol,
        newClients(),
        server,
        subEvents,
        nodeEvents
    )
    #Set the result to it.
    result = network

    try:
        #On a new message...
        subEvents.on(
            "message",
            proc (msg: Message): Future[bool] {.async.} =
                #Set the result to true.
                result = true

                #Switch based off the message type (in a try to handle invalid messages).
                try:
                    case msg.content:
                        of MessageType.Verification:
                            if nodeEvents.get(
                                proc (verif: MemoryVerification): bool,
                                "merit.verification"
                            )(
                                msg.message.parseVerification()
                            ):
                                network.clients.broadcast(msg)

                        of MessageType.Block:
                            if await nodeEvents.get(
                                proc (newBlock: Block): Future[bool],
                                "merit.block"
                            )(
                                msg.message.parseBlock()
                            ):
                                network.clients.broadcast(msg)

                        of MessageType.Claim:
                            var claim: Claim = msg.message.parseClaim()
                            if nodeEvents.get(
                                proc (claim: Claim): bool,
                                "lattice.claim"
                            )(claim):
                                network.clients.broadcast(msg)

                        of MessageType.Send:
                            var send: Send = msg.message.parseSend()
                            if nodeEvents.get(
                                proc (send: Send): bool,
                                "lattice.send"
                            )(send):
                                network.clients.broadcast(msg)

                        of MessageType.Receive:
                            var recv: Receive = msg.message.parseReceive()
                            if nodeEvents.get(
                                proc (recv: Receive): bool,
                                "lattice.receive"
                            )(recv):
                                network.clients.broadcast(msg)

                        of MessageType.Data:
                            var data: Data = msg.message.parseData()
                            if nodeEvents.get(
                                proc (data: Data): bool,
                                "lattice.data"
                            )(data):
                                network.clients.broadcast(msg)

                        of MessageType.BlockRequest:
                            var
                                requested: uint = uint(msg.message.fromBinary)
                                nonce: uint =
                                    nodeEvents.get(
                                        proc (): uint,
                                        "merit.getHeight"
                                    )()

                            if nonce <= requested:
                                #If they're requesting a Block we don't have, return DataMissing.
                                network.clients.reply(
                                    msg,
                                    char(MessageType.DataMissing) &
                                    char(0)
                                )
                            else:
                                network.clients.reply(
                                    msg,
                                    char(MessageType.Block) &
                                    !(
                                        nodeEvents.get(
                                            proc (nonce: uint): Block,
                                            "merit.getBlock"
                                        )(nonce).serialize()
                                    )
                                )

                        of MessageType.EntryRequest:
                            #Entry and header variables.
                            var
                                entry: Entry
                                msgType: char

                            try:
                                #Get the Entry the Client wants.
                                entry = network.nodeEvents.get(
                                    proc (hash: string): Entry,
                                    "lattice.getEntryByHash"
                                )(msg.message)
                            except:
                                #If that failed, return DataMissing.
                                network.clients.reply(
                                    msg,
                                    char(MessageType.DataMissing) &
                                    char(0)
                                )

                            #If we did get an Entry...
                            #Add the Message Type.
                            case entry.descendant:
                                of EntryType.Mint:
                                    #We do not Serialize Mints for Network transmission.
                                    discard
                                of EntryType.Claim:
                                    msgType = char(MessageType.Claim)
                                of EntryType.Send:
                                    msgType = char(MessageType.Send)
                                of EntryType.Receive:
                                    msgType = char(MessageType.Receive)
                                of EntryType.Data:
                                    msgType = char(MessageType.Data)
                                of EntryType.MeritRemoval:
                                    #Ignore this for now.
                                    discard

                            #Send over the Entry.
                            network.clients.reply(msg, msgType & !entry.serialize())

                        else:
                            discard

                except:
                    echo "Invalid Message."
        )
    except:
        raise newException(AsyncError, "Couldn't add the Network's Message Event.")

#Start listening.
proc start*(
    network: Network,
    port: uint
) {.raises: [AsyncError, SocketError].} =
    #Listen for a new Server client.
    network.subEvents.on(
        "client",
        proc (client: tuple[address: string, client: AsyncSocket]) {.raises: [AsyncError].} =
            try:
                asyncCheck network.add(client.address, port, client.client)
            except:
                raise newException(AsyncError, "Couldn't add a Client to the Network.")
    )

    try:
        #Start the server.
        asyncCheck network.listen(port)
    except:
        raise newException(SocketError, "Couldn't start the Network's Server Socket.")

#Connect to another node.
proc connect*(
    network: Network,
    ip: string,
    port: uint
) {.async.} =
    #Create the socket.
    var socket: AsyncSocket = newAsyncSocket()
    #Connect.
    await socket.connect(ip, Port(port))
    #Add the node to the clients.
    asyncCheck network.add(ip, port, socket)

#Get a Block.
proc requestBlock*(
    network: Network,
    nonce: uint
): Future[bool] {.async.} =
    #Try block is here so if anything fails, we still send Stop Syncing.
    try:
        #Send syncing.
        await network.clients.clients[0].send(
            char(MessageType.Syncing) &
            char(0)
        )

        #Send the Request.
        await network.clients.clients[0].send(
            char(MessageType.BlockRequest) &
            !nonce.toBinary()
        )

        #Parse it.
        var newBlock: Block
        try:
            newBlock = (await network.clients.clients[0].recv()).msg.parseBlock()
        except:
            return false

        #Get all the Entries it verifies.
        if not await newBlock.sync(network, network.clients.clients[0]):
            return false

        #Add the block.
        return await network.nodeEvents.get(
            proc (newBlock: Block): Future[bool],
            "merit.block"
        )(newBlock)

    except:
        #Raise whatever Exception occurred.
        raise

    finally:
        #Send syncing over.
        await network.clients.clients[0].send(
            char(MessageType.SyncingOver) &
            char(0)
        )

#Shutdown network operations.
proc shutdown*(network: Network) {.raises: [SocketError].} =
    try:
        #Stop the server.
        network.server.close()
    except:
        raise newException(SocketError, "Couldn't close the Network's server socket.")
    #Disconnect the clients.
    network.clients.shutdown()

#Function wrappers for the functions in Clients that take in Clients, not Network.
#Sends a message to all clients.
proc broadcast*(network: Network, msg: Message) {.raises: [AsyncError].} =
    network.clients.broadcast(msg)
#Reply to a message.
proc reply*(network: Network, msg: Message, toSend: string) {.raises: [AsyncError].} =
    network.clients.reply(msg, toSend)
#Disconnect a client.
proc disconnect*(network: Network, id: uint) {.raises: [].} =
    network.clients.disconnect(id)
proc disconnect*(network: Network, msg: Message) {.raises: [].} =
    network.clients.disconnect(msg.client)
