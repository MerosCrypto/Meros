#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#GlobalFunctionBox object.
import ../../objects/GlobalFunctionBoxObj

#Message object.
import MessageObj

#Manager objects.
import LiveManagerObj
import SyncManagerObj

#Peer library.
import ../Peer as PeerFile

#SerializeCommon lib.
import ../Serialize/SerializeCommon

#Random standard lib.
import random

#Tables standard lib.
import tables

#Networking standard libs.
import asyncdispatch
import asyncnet

#Network object.
type Network* = ref object
    #Used to provide each Peer an unique ID.
    count*: int
    #Table of every Peer.
    peers*: Table[int, Peer]
    #IDs of every Peer.
    ids*: seq[int]
    #Set of the IPs of our peers who have Live sockets.
    live*: Table[string, int]
    #Set of the IPs of our peers who have Sync sockets.
    sync*: Table[string, int]

    #Server.
    server*: AsyncSocket

    #Live Manager.
    liveManager*: LiveManager
    #Sync Manager.
    syncManager*: SyncManager

    #Global Function Box.
    functions*: GlobalFunctionBox

#Constructor.
proc newNetwork*(
    network: int,
    protocol: int,
    port: int,
    functions: GlobalFunctionBox
): Network {.forceCheck: [].} =
    var network: Network = Network(
        #Starts at 1 because the local node is 0.
        count: 1,
        peers: initTable[int, Peer](),
        ids: @[],
        live: initTable[string, int](),
        sync: initTable[string, int](),

        liveManager: newLiveManager(
            network,
            protocol,
            port,
            functions
        ),
        syncManager: newSyncManager(
            network,
            protocol,
            port,
            functions
        ),

        functions: functions
    )
    result = network

    #Add a repeating timer to remove inactive Peers.
    proc removeInactive() {.forceCheck: [], async.} =
        var
            p: int = 0
            peer: Peer
        while p < network.ids.len:
            #Grab the peer.
            try:
                peer = network.peers[network.ids[p]]
            except KeyError as e:
                doAssert(false, "Failed to get a peer we have an ID for: " & e.msg)

            #Close Peers who have been inactive for half a minute.
            if peer.isClosed or (peer.last + 30 <= getTime()):
                peer.close()
                network.live.del(peer.ip)
                network.sync.del(peer.ip)
                network.peers.del(network.ids[p])
                network.ids.del(p)
                continue

            #Handshake with Peers who have been inactive for 20 seconds.
            if peer.last + 20 <= getTime():
                #Send the handshake.
                var tail: Hash[256] = network.functions.merit.getTail()
                try:
                    await peer.sendLive(
                        newMessage(
                            MessageType.Handshake,
                            char(network.liveManager.protocol) &
                            char(network.liveManager.network) &
                            network.liveManager.services &
                            network.liveManager.port.toBinary(PORT_LEN) &
                            tail.toString()
                        )
                    )
                except PeerError:
                    #This will remove them on the next check.
                    peer.close()
                except Exception as e:
                    doAssert(false, "Sending to a Peer threw an Exception despite catching all thrown Exceptions: " & e.msg)

            #Move on to the next Peer.
            inc(p)
    try:
        asyncCheck removeInactive()
    except Exception as e:
        doAssert(false, "Failed to start the function which removes inactive Peers: " & e.msg)

#Add a peer.
proc add*(
    network: Network,
    peer: Peer
) {.forceCheck: [].} =
    peer.id = network.count
    inc(network.count)

    network.peers[peer.id] = peer
    network.ids.add(peer.id)

#Get random peers which meet criteria.
proc getPeers*(
    network: Network,
    reqArg: int,
    skip: int = 1,
    live: bool = false,
    server: bool = false
): seq[Peer] {.forceCheck: [].} =
    var
        req: int = reqArg
        peersLeft: int = network.peers.len
    for peer in network.peers.values():
        if req == 0:
            break

        if rand(peersLeft - 1) < req:
            #Skip peers who aren't servers if that's a requirement.
            if server and (not peer.server):
                dec(peersLeft)
                if req > peersLeft:
                    dec(req)
                continue

            #Skip peers who don't have a Live socket if that's a requirement.
            if live and peer.live.isNil:
                dec(peersLeft)
                if req > peersLeft:
                    dec(req)
                continue

            #Skip the Peer who sent us this message.
            if peer.id == skip:
                dec(peersLeft)
                if req > peersLeft:
                    dec(req)
                continue

            #Add the peers to the result, delete them from usable, and lower req.
            result.add(peer)
            dec(peersLeft)
            dec(req)

#Disconnect a peer.
proc disconnect*(
    network: Network,
    peer: Peer
) {.forceCheck: [].} =
    #Close the peer and delete it from the tables.
    peer.close()
    network.peers.del(peer.id)
    network.live.del(peer.ip)
    network.sync.del(peer.ip)

    #Delete its ID.
    for p in 0 ..< network.ids.len:
        if peer.id == network.ids[p]:
            network.ids.del(p)
            break

#Disconnects every Peer.
proc shutdown*(
    network: Network
) {.forceCheck: [].} =
    #Delete the first Peer until there is no first Peer.
    while network.ids.len != 0:
        try:
            network.peers[network.ids[0]].close()
        except Exception:
            discard

        network.peers.del(network.ids[0])
        network.ids.del(0)
