#Send libs.
import ../Database/Lattice/Send
import Serialize/ParseSend

#Receive libs.
import ../Database/Lattice/Receive
import Serialize/ParseReceive

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
    MIN_PROTOCOL: int = 0
    #Maximum supported protocol.
    MAX_PROTOCOL: int = 0

#Constructor.
proc newNetwork*(id: int, nodeEvents: EventEmitter): Network {.raises: [OSError, Exception].} =
    #Event emitter for the socket sublibraries.
    var subEvents: EventEmitter = newEventEmitter()

    #Create the Network object.
    var network: Network = newNetworkObj(
        id,
        newClients(),
        newAsyncSocket(),
        subEvents,
        nodeEvents
    )
    #Set the result to it.
    result = network

    #On a new message...
    subEvents.on(
        "new",
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
                    of MessageType.Send:
                        if nodeEvents.get(
                            proc (send: Send): bool,
                            "send"
                        )(
                            msg.message.parseSend()
                        ):
                            network.clients.broadcast(msg)
                    of MessageType.Receive:
                        if nodeEvents.get(
                            proc (recv: Receive): bool,
                            "recv"
                        )(
                            msg.message.parseReceive()
                        ):
                            network.clients.broadcast(msg)
                    of MessageType.Data:
                        discard
                    of MessageType.Verification:
                        discard
                    of MessageType.MeritRemoval:
                        discard
            except:
                echo "Invalid Message."
    )

#Start listening.
proc start*(
    network: Network,
    port: int = 5132
) {.raises: [ValueError, Exception].} =
    #Listen for a new Server client.
    network.subEvents.on(
        "server",
        proc (client: AsyncSocket) {.raises: [ValueError, Exception].} =
            network.add(client)
    )

    #Start the server.
    asyncCheck network.listen(port)

#Connect to another node.
proc connect*(network: Network, ip: string, port: int = 5132) {.async.} =
    #Create the socket.
    var socket: AsyncSocket = newAsyncSocket()
    #Connect.
    await socket.connect(ip, Port(port))
    #Add the node to the clients.
    network.add(socket)

#Shutdown network operations.
proc shutdown*(network: Network) {.raises: [Exception].} =
    #Mark the Server as not listening.
    network.listening = false
    #Stop the server.
    network.server.close()
    #Disconnect the clients.
    network.clients.shutdown()

#Function wrappers for the functions in Clients that take in Clients, not Network.
#Sends a message to all clients.
proc broadcast*(network: Network, msg: Message) {.raises: [Exception].} =
    network.clients.broadcast(msg)
#Reply to a message.
proc reply*(network: Network, msg: Message, toSend: string) {.raises: [Exception].} =
    network.clients.reply(msg, toSend)
#Disconnect a client.
proc disconnect*(network: Network, id: int) {.raises: [Exception].} =
    network.clients.disconnect(id)
proc disconnect*(network: Network, msg: Message) {.raises: [Exception].} =
    network.clients.disconnect(msg.client)
