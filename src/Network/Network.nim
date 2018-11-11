#Errors lib.
import ../lib/Errors

#Merit lib.
import ../Database/Merit/Merit

#Latice lib.
import ../Database/Lattice/Lattice

#Serialization libs.
import Serialize/SerializeCommon
import Serialize/Lattice/SerializeEntry

#Parsing libs.
import Serialize/Merit/ParseVerifications
import Serialize/Merit/ParseBlock
import Serialize/Lattice/ParseClaim
import Serialize/Lattice/ParseSend
import Serialize/Lattice/ParseReceive
import Serialize/Lattice/ParseData

#Message/Clients/Network objects.
import objects/MessageObj
import objects/ClientsObj
import objects/NetworkObj
#Export the Message and Network objects.
export MessageObj
export NetworkObj

#Socket sublibs.
import Server
import Clients

#Events lib.
import ec_events

#Networking standard libs.
import asyncnet, asyncdispatch

#String utils standard lib.
import strutils

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

                #Validate the network ID.
                if msg.network != id:
                    return false

                #Validate the protocol.
                if msg.protocol != protocol:
                    return false

                #Verify the message length.
                if ord(msg.header[3]) != msg.message.len:
                    return false

                #Switch based off the message type (in a try to handle invalid messages).
                try:
                    case msg.content:
                        of MessageType.Handshake:
                            discard

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
                            discard nodeEvents.get(
                                proc (claim: Claim): bool,
                                "lattice.claim"
                            )(
                                msg.message.parseClaim()
                            )

                        of MessageType.Send:
                            discard nodeEvents.get(
                                proc (send: Send): bool,
                                "lattice.send"
                            )(
                                msg.message.parseSend()
                            )

                        of MessageType.Receive:
                            discard nodeEvents.get(
                                proc (recv: Receive): bool,
                                "lattice.receive"
                            )(
                                msg.message.parseReceive()
                            )

                        of MessageType.Data:
                            discard nodeEvents.get(
                                proc (data: Data): bool,
                                "lattice.data"
                            )(
                                msg.message.parseData()
                            )

                        of MessageType.EntryRequest:
                            #Entry and header variables.
                            var
                                entry: Entry
                                header: string =
                                    char(network.id) &
                                    char(network.protocol)

                            try:
                                #Get the Entry the Client wants.
                                entry = network.nodeEvents.get(
                                    proc (hash: string): Entry,
                                    "lattice.getEntry"
                                )(msg.message)
                            except:
                                #If that failed, return EntryMissing.
                                header &= char(MessageType.EntryMissing)
                                network.clients.reply(msg, header & !msg.message)
                                return

                            #If we did get an Entry...
                            #Add the Message Type.
                            case entry.descendant:
                                of EntryType.Mint:
                                    #We do not Serialize Mints for Network transmission.
                                    discard
                                of EntryType.Claim:
                                    header &= char(MessageType.Claim)
                                of EntryType.Send:
                                    header &= char(MessageType.Send)
                                of EntryType.Receive:
                                    header &= char(MessageType.Receive)
                                of EntryType.Data:
                                    header &= char(MessageType.Data)
                                of EntryType.MeritRemoval:
                                    #Ignore this for now.
                                    discard

                            #Send over the Entry.
                            network.clients.reply(msg, header & !entry.serialize())

                        of MessageType.EntryMissing:
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
        proc (client: AsyncSocket) {.raises: [AsyncError].} =
            try:
                asyncCheck network.add(client)
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
    port: int
) {.async.} =
    #Create the socket.
    var socket: AsyncSocket = newAsyncSocket()
    #Connect.
    await socket.connect(ip, Port(port))
    #Add the node to the clients.
    await network.add(socket)

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
proc broadcast*(network: Network, msg: Message) {.raises: [AsyncError, SocketError].} =
    network.clients.broadcast(msg)
#Reply to a message.
proc reply*(network: Network, msg: Message, toSend: string) {.raises: [AsyncError, SocketError].} =
    network.clients.reply(msg, toSend)
#Disconnect a client.
proc disconnect*(network: Network, id: uint) {.raises: [SocketError].} =
    network.clients.disconnect(id)
proc disconnect*(network: Network, msg: Message) {.raises: [SocketError].} =
    network.clients.disconnect(msg.client)
