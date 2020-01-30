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
    peers*: TableRef[int, Peer]
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
    protocol: int,
    networkID: int,
    port: int,
    functions: GlobalFunctionBox
): Network {.forceCheck: [].} =
    var network: Network = Network(
        #Starts at 1 because the local node is 0.
        count: 1,
        peers: newTable[int, Peer](),
        ids: @[],
        live: initTable[string, int](),
        sync: initTable[string, int](),

        functions: functions
    )

    network.liveManager = newLiveManager(
        protocol,
        networkID,
        port,
        network.peers,
        functions
    )
    network.syncManager = newSyncManager(
        protocol,
        networkID,
        port,
        network.peers,
        functions
    )

    result = network

    #Add a repeating timer to remove inactive Peers.
    proc removeInactive(
        fd: AsyncFD
    ): bool {.forceCheck: [].} =
        {.gcsafe.}:
            var
                p: int = 0
                peer: Peer
            while p < network.ids.len:
                #Grab the peer.
                try:
                    peer = network.peers[network.ids[p]]
                except KeyError as e:
                    #Not a panic due to GC safety rules.
                    doAssert(false, "Failed to get a peer we have an ID for: " & e.msg)

                #Exclude closed sockets from live/sync.
                if peer.live.isNil or peer.live.isClosed:
                    network.live.del(peer.ip)
                if peer.sync.isNil or peer.sync.isClosed:
                    network.sync.del(peer.ip)

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
                    #Send the Handshake.
                    try:
                        if (not peer.live.isNil) and (not peer.live.isClosed):
                            asyncCheck peer.sendLive(
                                newMessage(
                                    MessageType.Handshake,
                                    char(network.liveManager.protocol) &
                                    char(network.liveManager.network) &
                                    network.liveManager.services &
                                    network.liveManager.port.toBinary(PORT_LEN) &
                                    network.functions.merit.getTail().toString()
                                )
                            )
                        else:
                            asyncCheck peer.sendSync(
                                newMessage(
                                    MessageType.Syncing,
                                    char(network.liveManager.protocol) &
                                    char(network.liveManager.network) &
                                    network.liveManager.services &
                                    network.liveManager.port.toBinary(PORT_LEN) &
                                    network.functions.merit.getTail().toString()
                                )
                            )
                    except SocketError:
                        discard
                    except Exception as e:
                        doAssert(false, "Sending to a Peer threw an Exception despite catching all thrown Exceptions: " & e.msg)

                #Move on to the next Peer.
                inc(p)

    try:
        addTimer(
            8000,
            false,
            removeInactive
        )
    except Exception as e:
        panic("Failed to start the function which removes inactive Peers: " & e.msg)

#Add a peer.
proc add*(
    network: Network,
    peer: Peer
) {.forceCheck: [].} =
    peer.id = network.count
    inc(network.count)

    network.peers[peer.id] = peer
    network.ids.add(peer.id)

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
