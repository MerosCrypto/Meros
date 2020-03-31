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

#Verify the validity of an address.
#If the address isn't IPv4, it's invalid (unfortunately).
#If the IP is ours, it's invalid. We check later if it's our public IP.
#If the IP already has both sockets, it's invalid.
proc verifyAddress(
    network: Network,
    address: TransportAddress
): tuple[
    ip: string,
    valid: bool,
    hasLive: bool,
    hasSync: bool
] {.forceCheck: [].} =
    if address.family != AddressFamily.IPv4:
        result.valid = false
        return

    result.ip = char(address.address_v4[0]) & char(address.address_v4[1]) & char(address.address_v4[2]) & char(address.address_v4[3])
    result.hasLive = network.live.hasKey(result.ip)
    result.hasSync = network.sync.hasKey(result.ip)

    result.valid = not (
        #Most common case.
        (result.hasLive and result.hasSync) or
        #Most malicious case.
        address.isLoopback() or
        #A malicious case.
        address.isMulticast() or
        #Invalid address.
        address.isZero() or
        #This should never happen.
        address.isUnspecified()
    )

proc isOurPublicIP(
    socket: StreamTransport
): bool {.forceCheck: [].} =
    try:
        result = socket.localAddress.address_v4 == socket.remoteAddress.address_v4
    #If we couldn't get the local or peer address, we can either panic or shut down this socket.
    #The safe way to shut down the socket is to return that's invalid.
    #That said, this can have side effects when we implement peer karma.
    except TransportError as e:
        panic("Trying to handle a socket which isn't a socket: " & e.msg)
    except TransportOSError:
        result = true

#Connect to a new Peer.
proc connect*(
    network: Network,
    address: string,
    port: int
) {.forceCheck: [], async.} =
    logDebug "Connecting", address = address, port = port

    #Lock the IP to stop multiple connections from happening at once.
    #We unlock the IP where we call connect.
    #If it's already locked, don't bother trying to connect.
    try:
        if not await network.lockIP(address):
            return
    except Exception as e:
        panic("Locking an IP raised an Exception despite not raising any Exceptions: " & e.msg)

    #Create a TransportAddress and verify it.
    var
        tAddy: TransportAddress
        verified: tuple[
            ip: string,
            valid: bool,
            hasLive: bool,
            hasSync: bool
        ]
    try:
        tAddy = initTAddress(address, port)
    except TransportAddressError:
        return
    verified = network.verifyAddress(tAddy)
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
        if socket.isOurPublicIP():
            raise newException(Exception, "")
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
            peer.close()
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
    #Get their address.
    var address: string
    try:
        address = $IpAddress(
            family: IpAddressFamily.IPv4,
            address_v4: socket.remoteAddress.address_v4
        )
    except TransportError as e:
        panic("Trying to handle a socket which isn't a socket: " & e.msg)
    logDebug "Accepting ", address = address

    #Receive the Handhshake.
    var handshake: Message
    try:
        handshake = await recv(0, socket, HANDSHAKE_LENS)
    except SocketError:
        return
    except PeerError:
        socket.safeClose()
        return
    except Exception as e:
        panic("Couldn't receive from a socket despite catching all errors recv throws: " & e.msg)

    #Lock the IP, passing the type of the Handshake.
    #Since up to two client connections can exist, it's fine if there's already one, as long as they're of different types.
    var lock: uint8 = if handshake.content == MessageType.Handshake: LIVE_IP_LOCK else: SYNC_IP_LOCK
    try:
        if not await network.lockIP(address, lock):
            socket.safeClose()
            return
    except Exception as e:
        panic("Locking an IP raised an Exception despite not raising any Exceptions: " & e.msg)

    var
        tAddy: TransportAddress
        verified: tuple[
            ip: string,
            valid: bool,
            hasLive: bool,
            hasSync: bool
        ]
    try:
        tAddy = initTAddress(address)
    except TransportAddressError as e:
        panic("Couldn't create a TransportAddress out of a peer's address: " & e.msg)
    verified = network.verifyAddress(tAddy)
    if (not verified.valid) or socket.isOurPublicIP():
        socket.safeClose()
        try:
            await network.unlockIP(address, lock)
        except Exception as e:
            panic("Unlocking an IP raised an Exception despite not raising any Exceptions: " & e.msg)
        return

    var peer: Peer
    #If there's a sync socket, this is a live socket.
    if verified.hasSync:
        try:
            peer = network.peers[network.sync[verified.ip]]
        except KeyError:
            socket.safeClose()
            try:
                await network.unlockIP(address, lock)
            except Exception as e:
                panic("Unlocking an IP raised an Exception despite not raising any Exceptions: " & e.msg)
            return

        peer.live = socket
    #If there's a live socket, this is a sync socket.
    elif verified.hasLive:
        try:
            peer = network.peers[network.live[verified.ip]]
        except KeyError:
            socket.safeClose()
            try:
                await network.unlockIP(address, lock)
            except Exception as e:
                panic("Unlocking an IP raised an Exception despite not raising any Exceptions: " & e.msg)
            return

        peer.sync = socket
    #If there's no socket, we need to switch off of the handshake.
    else:
        peer = newPeer(verified.ip)
        network.add(peer)
        if handshake.content == MessageType.Handshake:
            peer.live = socket
            network.live[verified.ip] = peer.id
        else:
            peer.sync = socket
            network.sync[verified.ip] = peer.id

    #Unlock the IP.
    try:
        await network.unlockIP(address, lock)
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
    else:
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
