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

    #Don't allow connections to self.
    if (not network.server.isClosed) and (address == "127.0.0.1") and (port == network.liveManager.port):
        return

    #Create a socket.
    var socket: AsyncSocket
    try:
        socket = newAsyncSocket()
        await socket.connect(address, Port(port))
    except Exception:
        socket.safeClose()
        return

    var
        addressParts: seq[string]
        ip: string
    try:
        addressParts = socket.getPeerAddr()[0].split(".")
        ip = (
            char(parseInt(addressParts[0])) &
            char(parseInt(addressParts[1])) &
            char(parseInt(addressParts[2])) &
            char(parseInt(addressParts[3]))
        )
    except OSError:
        socket.safeClose()
        return
    except ValueError:
        raise newLoggedException(PeerError, "Invalid IP.")

    #If we're already connected, don't create a new peer. Just create the missing connection, if possible.
    var
        peer: Peer
        hasLive: bool = network.live.hasKey(ip)
        hasSync: bool = network.sync.hasKey(ip)
        live: AsyncSocket = nil
        sync: AsyncSocket = nil

    #Don't connect to someone we've already connected to.
    if hasLive and hasSync:
        return

    #Try to get the existing Peer.
    if hasLive:
        try:
            peer = network.peers[network.live[ip]]
        except KeyError:
            panic("Peer has a live socket but either not an entry in the live table or the peers table.")

        live = peer.live
        sync = peer.sync
    elif hasSync:
        try:
            peer = network.peers[network.sync[ip]]
        except KeyError:
            panic("Peer has a sync socket but either not an entry in the sync table or the peers table.")

        live = peer.live
        sync = peer.sync

    try:
        #Create the Sync socket if necessary.
        if not hasSync:
            sync = socket
            socket = nil
        #Create the Live socket if necessary.
        if not hasLive:
            live = socket
            if live.isNil:
                live = newAsyncSocket()
                await live.connect(address, Port(port))
    except Exception:
        if not peer.isNil:
            peer.close()
            network.disconnect(peer)
        return

    #Create the Peer, if necessary.
    if peer.isNil:
        peer = newPeer(ip)
        network.add(peer)

    #Set the sockets.
    peer.live = live
    peer.sync = sync
    network.live[ip] = peer.id
    network.sync[ip] = peer.id

    #Handle the connections.
    logDebug "Handling Client connection", address = address, port = port

    try:
        if not hasSync:
            asyncCheck network.syncManager.handle(peer)
        if not hasLive:
            asyncCheck network.liveManager.handle(peer)
    except Exception as e:
        panic("Handling a new connection raised an Exception despite not throwing any Exceptions: " & e.msg)

#Handle a new connection.
proc handle(
    network: Network,
    socket: AsyncSocket
) {.forceCheck: [], async.} =
    #Get the IP.
    var
        address: string
        addressParts: seq[string]
    try:
        address = socket.getPeerAddr()[0]

        #Don't allow connections from our machine unless they're over localhost.
        if (socket.getLocalAddr()[0] == address) and (address != "127.0.0.1"):
            socket.safeClose()
            return

        addressParts = address.split(".")
    except OSError:
        socket.safeClose()
        return

    logDebug "Accepting ", address = address

    var ip: string
    try:
        ip = (
            char(parseInt(addressParts[0])) &
            char(parseInt(addressParts[1])) &
            char(parseInt(addressParts[2])) &
            char(parseInt(addressParts[3]))
        )
    except ValueError as e:
        panic("IP contained an invalid integer: " & e.msg)

    var first: string
    try:
        first = await socket.recv(1, {SocketFlag.Peek})
        if first.len != 1:
            raise newLoggedException(Exception, "")
    except Exception:
        socket.safeClose()
        return

    if not (int(first[0]) < int(MessageType.End)):
        socket.safeClose()
        return

    if not {MessageType.Handshake, MessageType.Syncing}.contains(MessageType(first[0])):
        socket.safeClose()
        return

    var peer: Peer
    if MessageType(first[0]) == MessageType.Handshake:
        if network.live.hasKey(ip) and (address != "127.0.0.1"):
            socket.safeClose()
            return

        try:
            peer = network.peers[network.sync[ip]]
        except KeyError:
            peer = newPeer(ip)
            network.add(peer)
        network.live[ip] = peer.id

        peer.live = socket
        try:
            logDebug "Handling Live Server connection", address = address
            asyncCheck network.liveManager.handle(peer)
        except PeerError:
            network.disconnect(peer)
        except Exception as e:
            panic("Handling a Live socket threw an Exception despite catching all Exceptions: " & e.msg)

    elif MessageType(first[0]) == MessageType.Syncing:
        if network.sync.hasKey(ip) and (address != "127.0.0.1"):
            socket.safeClose()
            return

        try:
            peer = network.peers[network.live[ip]]
        except KeyError:
            peer = newPeer(ip)
            network.add(peer)
        network.sync[ip] = peer.id

        peer.sync = socket
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
