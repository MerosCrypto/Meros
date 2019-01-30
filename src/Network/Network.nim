#Errors lib.
import ../lib/Errors

#Util lib.
import ../lib/Util

#Main Function Box.
import ../MainFunctionBox

#Message and Network objects.
import objects/MessageObj
import objects/NetworkObj
#Export the Message and Network objects.
export MessageObj
export NetworkObj

#Network Function Box.
import objects/NetworkLibFunctionBox

#Clients library.
import Clients

#Networking standard libs.
import asyncdispatch, asyncnet

#Constructor.
proc newNetwork*(
    id: uint,
    protocol: uint,
    mainFunctions: MainFunctionBox
): Network {.raises: [SocketError].} =
    #Create the server socket.
    var server: AsyncSocket
    try:
        server = newAsyncSocket()
    except:
        raise newException(SocketError, "Couldn't create a socket for the server.")

    #Create the Network.
    result = newNetworkObj(
        id,
        protocol,
        newClients(),
        server,
        newNetworkLibFunctionBox(),
        mainFunctions
    )

    #Provide functions for the Network Functions Box.
    result.networkFunctions.getNetworkID = proc (): uint {.raises: [].} =
        id

    result.networkFunctions.getProtocol = proc (): uint {.raises: [].} =
        protocol

    result.networkFunctions.getHeight = proc (): uint {.raises: [].} =
        mainFunctions.merit.getHeight()

    result.networkFunctions.handle = proc (msg: Message): bool {.raises: [].} =
        discard

#Listen on a port.
proc listen*(network: Network, port: uint) {.async.} =
    #Start listening.
    network.server.setSockOpt(OptReuseAddr, true)
    network.server.bindAddr(Port(port))
    network.server.listen()

    #Accept new connections infinitely.
    while not network.server.isClosed():
        #This is in a try/catch since ending the server while accepting a new Client will throw an Exception.
        try:
            #Accept a new client.
            var client: tuple[address: string, client: AsyncSocket] = await network.server.acceptAddr()
            #Pass it to Clients.
            asyncCheck network.clients.add(
                client.address,
                port,
                client.client,
                network.networkFunctions
            )
        except:
            continue

#Connect to a Client.
proc connect*(network: Network, ip: string, port: uint) {.async.} =
    #Create the socket.
    var socket: AsyncSocket = newAsyncSocket()
    #Connect.
    await socket.connect(ip, Port(port))
    #Pass it off to clients.
    asyncCheck network.clients.add(
        ip,
        port,
        socket,
        network.networkFunctions
    )

#Broadcast a message.
proc broadcast*(network: Network, msg: Message) {.raises: [].} =
    network.clients.broadcast(msg)

#Reply to a message.
proc reply*(network: Network, msg: Message, res: Message) {.raises: [].} =
    network.clients.reply(msg, res)

#Shutdown all Network operations.
proc shutdown*(network: Network) {.raises: [SocketError].} =
    try:
        #Stop the server.
        network.server.close()
    except:
        raise newException(SocketError, "Couldn't close the Network's server socket.")
    #Shutdown the clients.
    network.clients.shutdown()
