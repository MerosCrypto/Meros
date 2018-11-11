#Errors lib.
import ../lib/Errors

#Hash lib.
import ../lib/Hash

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

                #Validate the network ID.
                if msg.network != id:
                    return false

                #Validate the protocol.
                if msg.protocol != protocol:
                    return false

                #Verify the message length.
                if msg.len != uint(msg.message.len):
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
                            var claim = msg.message.parseClaim()
                            if nodeEvents.get(
                                proc (claim: Claim): bool,
                                "lattice.claim"
                            )(claim):
                                network.requests[claim.hash.toString()] = true

                        of MessageType.Send:
                            var send = msg.message.parseSend()
                            if nodeEvents.get(
                                proc (send: Send): bool,
                                "lattice.send"
                            )(send):
                                network.requests[send.hash.toString()] = true

                        of MessageType.Receive:
                            var recv = msg.message.parseReceive()
                            if nodeEvents.get(
                                proc (recv: Receive): bool,
                                "lattice.receive"
                            )(recv):
                                network.requests[recv.hash.toString()] = true

                        of MessageType.Data:
                            var data = msg.message.parseData()
                            if nodeEvents.get(
                                proc (data: Data): bool,
                                "lattice.data"
                            )(data):
                                network.requests[data.hash.toString()] = true

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
                                #If that failed, do nothing.
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

#Request an Entry from the other Nodes.
proc requestEntry*(
    network: Network,
    hash: string
) {.async.} =
    #Say that we haven't found the Entry yet.
    network.requests[hash] = false

    #Broadcast our request.
    network.clients.broadcast(
        newMessage(
            network.id,
            network.protocol,
            MessageType.EntryRequest,
            hash
        )
    )

    #Run for a maximum of one second.
    for _ in 0 ..< 1000:
        await sleepAsync(1)

        #Check to see if we got the entry.
        if network.requests[hash]:
            #If we did, return.
            return

    #This is in a if true block so the async macro doesn't think this whole proc is unreachable.
    if true:
        #If we exited the loop, meaning we never got that hash...
        raise newException(Exception, "Never got the requested Entry.")

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
