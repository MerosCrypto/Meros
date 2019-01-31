#Errors lib.
import ../lib/Errors

#Util lib.
import ../lib/Util

#Lattice lib (for all Entry types).
import ../Database/Lattice/Lattice

#Verifications lib (for Verification/MemoryVerification).
import ../Database/Verifications/Verifications

#Block lib.
import ../Database/Merit/Block as BlockFile

#Serialization common lib.
import Serialize/SerializeCommon

#Message object.
import objects/MessageObj

#Client library and Clients object.
import Client
import objects/ClientsObj
#Export Client/ClientsObj.
export Client
export ClientsObj

#Network Function Box.
import objects/NetworkLibFunctionBox

#Networking standard libs.
import asyncdispatch, asyncnet

#Handle a client.
proc handle(
    client: Client,
    networkFunctions: NetworkLibFunctionBox
) {.async.} =
    #Message loop variable.
    var msg: Message

    #While the client is still connected...
    while not client.isClosed():
        try:
            #Read in new messages.
            msg = await client.recv()
        except:
            continue

        #If this was a message changing the sync state, update it and return.
        if msg.content == MessageType.Syncing:
            client.theirState = ClientState.Syncing
            continue
        if msg.content == MessageType.SyncingOver:
            client.theirState = ClientState.Ready
            continue

        #Tell the Network of our new message.
        if not await networkFunctions.handle(msg):
            #If the message was invalid, disconnect the client and stop handling it.
            client.close()
            return

#Add a new Client from a socket.
proc add*(
    clients: Clients,
    ip: string,
    port: uint,
    socket: AsyncSocket,
    networkFunctions: NetworkLibFunctionBox
) {.async.} =
    #Make sure we aren't already connected to them.
    for client in clients:
        if (
            (client.ip == ip) and
            (client.port == port)
        ):
            return

    #Create the Client.
    var client: Client = newClient(
        ip,
        port,
        clients.count,
        socket
    )
    #Increase the count so the next client has an unique ID.
    inc(clients.count)

    #Handshake with the Client.
    var state: HandshakeState = await client.handshake(
        networkFunctions.getNetworkID(),
        networkFunctions.getProtocol(),
        networkFunctions.getHeight()
    )

    #If there was an error, return.
    if state == HandshakeState.Error:
        return

    #Add the new Client to Clients.
    clients.add(client)

    #Handle it.
    try:
        await client.handle(networkFunctions)
    except:
        #Due to async, the Exception we had here wasn't being handled.
        #Because it wasn't being handled, the Node crashed.
        #The Node shouldn't crash when a random Node disconnects.

        #Delete this client from Clients.
        clients.disconnect(client.id)

#Sends a message to all clients.
proc broadcast*(
    clients: Clients,
    msg: Message
) {.async.} =
    #Seq of the clients to disconnect.
    var toDisconnect: seq[uint] = @[]

    #Iterate over each client.
    for client in clients.clients:
        #Skip the Client who sent us this.
        if client.id == msg.client:
            continue

        #Skip Clients who are syncing.
        if client.theirState == ClientState.Syncing:
            continue

        #Try to send the message.
        try:
            await client.send(msg)
        #If that failed, mark the Client for disconnection.
        except:
            toDisconnect.add(client.id)

    #Disconnect the clients marked for disconnection.
    for id in toDisconnect:
        clients.disconnect(id)

#Reply to a message.
proc reply*(
    clients: Clients,
    msg: Message,
    res: Message
) {.async.} =
    #Get the client.
    var client: Client = clients[msg.client]

    #Try to send the message.
    try:
        await client.send(msg)
    #If that failed, mark the Client for disconnection.
    except:
        clients.disconnect(msg.client)

#Disconnect a client based off the message it sent.
proc disconnect*(
    clients: Clients,
    msg: Message
) {.raises: [].} =
    clients.disconnect(msg.client)
