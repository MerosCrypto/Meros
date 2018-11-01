#Errors lib.
import ../lib/Errors

#Merit lib.
import ../Database/Merit/Merit

#Latice lib.
import ../Database/Lattice/Lattice

#Parsing libs.
import Serialize/ParseVerification
import Serialize/ParseBlock
import Serialize/ParseClaim
import Serialize/ParseSend
import Serialize/ParseReceive
import Serialize/ParseData

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

const
    #Minimum supported protocol.
    MIN_PROTOCOL: uint = 0
    #Maximum supported protocol.
    MAX_PROTOCOL: uint = 0

#Constructor.
proc newNetwork*(
    id: uint,
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
                if msg.version < MIN_PROTOCOL:
                    return false
                if msg.version > MAX_PROTOCOL:
                    return false

                #Verify the message length.
                if ord(msg.header[3]) != msg.message.len:
                    return false

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
                            if nodeEvents.get(
                                proc (newBlock: Block): bool,
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

                except:
                    echo "Invalid Message."
        )
    except:
        raise newException(AsyncError, "Couldn't add the Network's message event.")

#Start listening.
proc start*(
    network: Network,
    port: uint
) {.raises: [AsyncError, SocketError].} =
    #Listen for a new Server client.
    network.subEvents.on(
        "client",
        proc (client: AsyncSocket) {.raises: [AsyncError].} =
            network.add(client)
    )

    try:
        #Start the server.
        asyncCheck network.listen(port)
    except:
        raise newException(SocketError, "Couldn't start the Network's server socket.")

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
    network.add(socket)

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
