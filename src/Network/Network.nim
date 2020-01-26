#Errors lib.
import ../lib/Errors

#Util lib.
import ../lib/Util

#Hash lib.
import ../lib/Hash

#Sketcher lib.
import ../lib/Sketcher

#Block object.
import ../Database/Merit/objects/BlockObj

#Elements lib.
import ../Database/Consensus/Elements/Elements

#Message object.
import objects/MessageObj

#SketchyBlock object.
import objects/SketchyBlockObj
export SketchyBlock

#Peer lib.
import Peer
export Peer

#Network object.
import objects/NetworkObj
export NetworkObj

#Math standard lib.
import math

#Networking standard libs.
import asyncdispatch, asyncnet

#Table standard lib.
import tables

#String utils standard lib.
import strutils

#Service bytes.
const SERVER_SERVICE*: uint8 = 0b10000000

#Handle a Peer's Live socket's messages.
proc handleLive(
    network: Network,
    peer: Peer,
    tail: Hash[256]
) {.forceCheck: [
    PeerError
], async.} =
    discard

#Sync a Block.
proc sync*(
    network: Network,
    sketchyBlock: SketchyBlock,
    sketcher: Sketcher
): Future[tuple[syncedBlock: Block, elements: seq[BlockElement]]] {.forceCheck: [
    ValueError,
    DataMissing
], async.} =
    discard

#Connect to a new Peer.
proc connect*(
    network: Network,
    address: string,
    port: int
) {.forceCheck: [
    PeerError
], async.} =
    #Don't allow connections to self.
    if (not network.server.isClosed) and (address == "127.0.0.1") and (port == network.port):
        return

    var
        addressParts: seq[string] = address.split(".")
        ip: string
    try:
        ip = (
            char(parseInt(addressParts[0])) &
            char(parseInt(addressParts[1])) &
            char(parseInt(addressParts[2])) &
            char(parseInt(addressParts[3]))
        )
    except ValueError:
        raise newException(PeerError, "Invalid IP.")

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
            doAssert(false, "Peer has a live socket but either not an entry in the live table or the peers table.")

        #Don't try to connect if it's not a server.
        if not peer.server:
            return

        live = peer.live
        sync = peer.sync
    elif hasSync:
        try:
            peer = network.peers[network.sync[ip]]
        except KeyError:
            doAssert(false, "Peer has a sync socket but either not an entry in the sync table or the peers table.")

        #Don't try to connect if it's not a server.
        if not peer.server:
            return

        live = peer.live
        sync = peer.sync

    try:
        #Create the Live socket if necessary.
        if not hasLive:
            live = newAsyncSocket()
            await live.connect(address, Port(port))
            await live.send(newMessage(
                MessageType.Handshake,
                char(network.network) &
                char(network.protocol) &
                network.port.toBinary() &
                network.services &
                network.functions.merit.getTail().toString()
            ).toString())

        #Create the Sync socket if necessary.
        if not hasSync:
            sync = newAsyncSocket()
            await sync.connect(address, Port(port))
            await sync.send(newMessage(
                MessageType.Syncing,
                char(network.network) &
                char(network.protocol) &
                network.port.toBinary() &
                network.services &
                network.functions.merit.getTail().toString()
            ).toString())
    except Exception:
        if not live.isNil:
            try:
                sync.close()
            except Exception as e:
                doAssert(false, "Couldn't close a socket: " & e.msg)

        if not sync.isNil:
            try:
                sync.close()
            except Exception as e:
                doAssert(false, "Couldn't close a socket: " & e.msg)

        if not peer.isNil:
            network.disconnect(peer)

        return

    #Create the Peer, if necessary.
    if peer.isNil:
        peer = newPeer(ip, true, port)
        network.add(peer)

    #Set the sockets.
    peer.live = live
    peer.sync = sync
    network.live[ip] = peer.id
    network.sync[ip] = peer.id

#Handle a new connection.
proc handle*(
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
            try:
                socket.close()
            except Exception as e:
                doAssert(false, "Failed to close a socket: " & e.msg)
            return

        addressParts = address.split(".")
    except OSError as e:
        doAssert(false, "Failed to get a peer's address: " & e.msg)

    var ip: string
    try:
        ip = (
            char(parseInt(addressParts[0])) &
            char(parseInt(addressParts[1])) &
            char(parseInt(addressParts[2])) &
            char(parseInt(addressParts[3]))
        )
    except ValueError as e:
        doAssert(false, "IP contained an invalid integer: " & e.msg)

    var first: string
    try:
        first = await socket.recv(1)
        if first.len != 1:
            raise newException(Exception, "")
    except Exception:
        try:
            socket.close()
        except Exception as e:
            doAssert(false, "Failed to close a socket: " & e.msg)
        return

    if not {MessageType.Handshake, MessageType.Syncing}.contains(MessageType(first[0])):
        try:
            socket.close()
        except Exception as e:
            doAssert(false, "Failed to close a socket: " & e.msg)
        return

    try:
        first &= await socket.recv(LIVE_LENS[MessageType.Handshake][0])
        if first.len != LIVE_LENS[MessageType.Handshake][0] + 1:
            raise newException(Exception, "")
    except KeyError as e:
        doAssert(false, "Couldn't get the length of the Handshake message: " & e.msg)
    except Exception:
        try:
            socket.close()
        except Exception as e:
            doAssert(false, "Failed to close a socket: " & e.msg)
        return

    if (int(first[1]) != network.network) or (int(first[2]) != network.protocol):
        try:
            socket.close()
        except Exception as e:
            doAssert(false, "Failed to close a socket: " & e.msg)
        return

    var
        server: bool
        port: int
        tail: Hash[256]
    if (uint8(first[3]) and SERVER_SERVICE) == SERVER_SERVICE:
        server = true
        port = first[4 ..< 6].fromBinary()
    try:
        tail = first[6 ..< 38].toHash(256)
    except ValueError as e:
        doAssert(false, "Failed to create a 32-byte hash out of a 32-byte piece of data: " & e.msg)

    var peer: Peer
    if MessageType(first[0]) == MessageType.Handshake:
        if network.live.hasKey(ip) and (address != "127.0.0.1"):
            try:
                socket.close()
            except Exception as e:
                doAssert(false, "Failed to close a socket: " & e.msg)
            return

        try:
            peer = network.peers[network.sync[ip]]
        except KeyError:
            peer = newPeer(ip, server, port)
            network.add(peer)
        network.live[ip] = peer.id

        peer.live = socket
        try:
            asyncCheck network.handleLive(peer, tail)
        except PeerError:
            network.disconnect(peer)
        except Exception as e:
            doAssert(false, "Handling a Live socket threw an Exception despite catching all Exceptions: " & e.msg)

    elif MessageType(first[0]) == MessageType.Syncing:
        if network.sync.hasKey(ip) and (address != "127.0.0.1"):
            try:
                socket.close()
            except Exception as e:
                doAssert(false, "Failed to close a socket: " & e.msg)
            return

        try:
            peer = network.peers[network.live[ip]]
        except KeyError:
            peer = newPeer(ip, server, port)
            network.add(peer)
        network.sync[ip] = peer.id

        peer.sync = socket
        #TODO: SyncManager.

#Listen for new Network.
proc listen*(
    network: Network
) {.forceCheck: [], async.} =
    #Start listening.
    try:
        network.server = newAsyncSocket()
    except Exception as e:
        doAssert(false, "Failed to create the Network's server socket: " & e.msg)

    try:
        network.server.setSockOpt(OptReuseAddr, true)
        network.server.bindAddr(Port(network.port))
    except Exception as e:
        doAssert(false, "Failed to set the Network's server socket options and bind it: " & e.msg)

    #Start listening.
    try:
        network.server.listen()
    except Exception as e:
        doAssert(false, "Failed to start listening on the Network's server socket: " & e.msg)

    #Update the services byte.
    network.services = char(uint8(network.services) or SERVER_SERVICE)

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
    #Network we need to broadcast to.
    var recipients: seq[Peer] = network.getPeers(
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
        except PeerError:
            network.disconnect(recipient)
        except Exception as e:
            doAssert(false, "Sending over a Live socket raised an Exception despite catching every Exception: " & e.msg)
