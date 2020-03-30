#Errors lib.
import ../lib/Errors

#Util lib.
import ../lib/Util

#Block object.
import ../Database/Merit/objects/BlockObj

#Elements lib.
import ../Database/Consensus/Elements/Elements

#Message object.
import objects/MessageObj
export MessageObj

#SketchyBlock object.
import objects/SketchyBlockObj
export SketchyBlockObj

#Peer lib.
import Peer
export Peer

#LiveManager object.
import objects/LiveManagerObj

#SyncManager lib.
import SyncManager
export SyncManager

#Network object.
import objects/NetworkObj
export NetworkObj

#Chronos external lib.
import chronos

#Math standard lib.
import math

#Table standard lib.
import tables

#String utils standard lib.
import strutils

#Connect to a new Peer.
proc connect*(
    network: Network,
    address: string,
    port: int
) {.forceCheck: [
    PeerError
], async.} =
    logDebug "Connecting", address = address, port = port

    #Lock the IP to stop multiple connections from happening at once.
    #We unlock the IP where we call connect.
    #If it's already locked, don't bother trying to connect.
    try:
        if not await network.lockIP(address):
            return
    except Exception as e:
        panic("Locking an IP raised an Exception despite not raising any Exceptions: " & e.msg)

    #Create a TAddress and verify it.
    var
        tAddy: TAddress = initTAddress(address & ":" & $port)
        verified: tuple[
            ip: string,
            valid: bool,
            hasLive: bool,
            hasSync: bool
        ] = network.verifyAddress(tAddy)
    if not verified.valid:
        try:
            await network.unlockIP(address)
        except Exception as e:
            panic("Unlocking an IP raised an Exception despite not raising any Exceptions: " & e.msg)
        return

    #Create a socket.
    var socket: StreamTransport
    try:
        socket = await connect(tAddy)
    except Exception:
        socket.safeClose()
        try:
            await network.unlockIP(address)
        except Exception as e:
            panic("Unlocking an IP raised an Exception despite not raising any Exceptions: " & e.msg)
        return

    #Variable for the peer.
    var peer: Peer

    #If we already have a live connection, set the sync socket.
    if verified.hasLive:
        try:
            peer = network.peers[network.live[verified.ip]]
            network.sync[verified.ip] = network.live[verified.ip]
        except KeyError:
            panic("Peer has a live socket but either not an entry in the live table or the peers table.")
        peer.sync = socket
    #If we already have a sync socket, set the live socket.
    elif verified.hasSync:
        try:
            peer = network.peers[network.sync[verified.ip]]
            network.live[verified.ip] = network.sync[verified.ip]
        except KeyError:
            panic("Peer has a sync socket but either not an entry in the sync table or the peers table.")
        peer.live = socket
    #If we don't have a peer, create one and set both sockets.
    else:
        peer = newPeer(verified.ip)
        peer.sync = socket
        try:
            peer.live = await connect(tAddy)
        except Exception:
            peer.safeClose()
            try:
                await network.unlockIP(address)
            except Exception as e:
                panic("Unlocking an IP raised an Exception despite not raising any Exceptions: " & e.msg)

        #Add it to the network.
        network.add(peer)
        network.live[verified.ip] = peer.id
        network.sync[verified.ip] = peer.id

    try:
        await network.unlockIP(address)
    except Exception as e:
        panic("Unlocking an IP raised an Exception despite not raising any Exceptions: " & e.msg)

    #Handle the connections.
    logDebug "Handling Client connection", address = address, port = port

    try:
        if not verified.hasSync:
            asyncCheck network.syncManager.handle(peer)
        if not verified.hasLive:
            asyncCheck network.liveManager.handle(peer)
    except Exception as e:
        panic("Handling a new connection raised an Exception despite not throwing any Exceptions: " & e.msg)

#Handle a new connection.
proc handle(
    network: Network,
    socket: StreamTransport
) {.forceCheck: [], async.} =
    logDebug "Accepting ", address = address

    #Receive the Handhshake.
    var handshake: Message
    try:
        handshake = await recv(
            0,
            socket,
            {
                MessageType.Handshake: LIVE_LENS[MessageType.Handshake],
                MessageType.Syncing:   SYNC_LENS[MessageType.Syncing],
            }.toTable()
        )
    except SocketError:
        return
    except PeerError:
        socket.safeClose()
        return

    #Get their address.
    var address: string = socket.getPeerAddr()[0]

    #Lock the IP, passing the type of the Handshake.
    #Since up to two client connections can exist, it's fine if there's already one, as long as they're of different types.
    var lock: uint8 = if handshake.content == MessageType.Handshake: LIVE_IP_LOCK else: SYNC_IP_LOCK
    try:
        if not await network.lockIP(address, lock):
            return
    except Exception as e:
        panic("Locking an IP raised an Exception despite not raising any Exceptions: " & e.msg)
    var
        tAddy: TAddress = initTAddress(address)
        verified: tuple[
            ip: string,
            valid: bool,
            hasLive: bool,
            hasSync: bool
        ] = network.verifyAddress(tAddy, handshake)
    if not verified.valid:
        try:
            await network.unlockIP(address, lock)
        except Exception as e:
            panic("Unlocking an IP raised an Exception despite not raising any Exceptions: " & e.msg)
        return

    #If there's a sync socket, this is a live socket.
    if verified.hasSync:
        network.peers[network.sync[verified.ip]].live = socket
    #If there's a live socket, this is a sync socket.
    elif verified.hasLive:
        network.peers[network.live[verified.ip]].sync = socket
    #If there's no socket, we need to switch off of the handshake.
    else:
        var peer: Peer = newPeer(ip)
        network.add(peer)
        if handshake.content == MessageType.Handshake:
            peer.live = socket
            network.live[verified.ip] = peer.id
        else:
            peer.sync = socket
            network.sync[verified.ip] = peer.id

    #Unlock the IP.
    try:
        network.unlockIP(address, lock)
    except Exception as e:
        panic("Unlocking an IP raised an Exception despite not raising any Exceptions: " & e.msg)

    if handshake.content == MessageType.Handshake:
        try:
            logDebug "Handling Live Server connection", address = address
            asyncCheck network.liveManager.handle(peer)
        except PeerError:
            network.disconnect(peer)
        except Exception as e:
            panic("Handling a Live socket threw an Exception despite catching all Exceptions: " & e.msg)
    else
        try:
            logDebug "Handling Sync Server connection", address = address
            asyncCheck network.syncManager.handle(peer)
        except PeerError:
            network.disconnect(peer)
        except Exception as e:
            panic("Handling a Sync socket threw an Exception despite catching all Exceptions: " & e.msg)

#Listen for new Network.
proc listen*(
    network: Network
) {.forceCheck: [], async.} =
    logDebug "Listening", port = network.liveManager.port

    #Update the services byte.
    network.liveManager.updateServices(SERVER_SERVICE)
    network.syncManager.updateServices(SERVER_SERVICE)

    #Start listening.
    try:
        network.server = newAsyncSocket()
    except Exception as e:
        panic("Failed to create the Network's server socket: " & e.msg)

    try:
        network.server.setSockOpt(OptReuseAddr, true)
        network.server.bindAddr(Port(network.liveManager.port))
    except Exception as e:
        panic("Failed to set the Network's server socket options and bind it: " & e.msg)

    #Start listening.
    try:
        network.server.listen()
    except Exception as e:
        panic("Failed to start listening on the Network's server socket: " & e.msg)

    #Accept new connections infinitely.
    while not network.server.isClosed():
        #Accept and handle a new connection.
        #This is in a try/catch since ending the server while accepting a new Peer will throw an Exception.
        try:
            asyncCheck network.handle(await network.server.accept())
        except Exception:
            continue

#Broadcast a message to our Network.
proc broadcast*(
    network: Network,
    msg: Message
) {.forceCheck: [], async.} =
    #Peers we're broadcasting to.
    var recipients: seq[Peer] = network.peers.getPeers(
        max(
            min(network.peers.len, 3),
            int(ceil(sqrt(float(network.peers.len))))
        ),
        -1,
        live = true
    )

    for recipient in recipients:
        try:
            await recipient.sendLive(msg)
        except SocketError:
            discard
        except Exception as e:
            panic("Sending over a Live socket raised an Exception despite catching every Exception: " & e.msg)
