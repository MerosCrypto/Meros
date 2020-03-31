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

#Chronos external lib.
import chronos

#Locks standard lib.
import locks

#Tables standard lib.
import tables

#IP lock masks.
const
    CLIENT_IP_LOCK: uint8 = 1
    LIVE_IP_LOCK*: uint8 = 2
    SYNC_IP_LOCK*: uint8 = 4

#Network object.
type Network* = ref object
    #Lock for the IP masks.
    ipLock: Lock
    #IP masks.
    masks: Table[string, uint8]

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
    server*: StreamServer

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
        masks: initTable[string, uint8](),

        #Starts at 1 because the local node is 0.
        count: 1,
        peers: newTable[int, Peer](),
        ids: @[],
        live: initTable[string, int](),
        sync: initTable[string, int](),

        functions: functions
    )
    initLock(network.ipLocK)

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
    proc removeInactive(data: pointer = nil) {.gcsafe, forceCheck: [].} =
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
            if peer.live.isNil or peer.live.closed:
                network.live.del(peer.ip)
            if peer.sync.isNil or peer.sync.closed:
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
                    if (not peer.live.isNil) and (not peer.live.closed):
                        asyncCheck peer.sendLive(
                            newMessage(
                                MessageType.Handshake,
                                char(network.liveManager.protocol) &
                                char(network.liveManager.network) &
                                network.liveManager.services &
                                network.liveManager.port.toBinary(PORT_LEN) &
                                network.functions.merit.getTail().toString()
                            ),
                            true
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
                            ),
                            true
                        )
                except SocketError:
                    discard
                except Exception as e:
                    panic("Sending to a Peer threw an Exception despite catching all thrown Exceptions: " & e.msg)

            #Move on to the next Peer.
            inc(p)

        #Register the timer again.
        try:
            discard setTimer(Moment.fromNow(seconds(10)), removeInactive)
        except OSError as e:
            panic("Re-setting a timer to remove inactive peers failed: " & e.msg)

    try:
        discard setTimer(Moment.fromNow(seconds(10)), removeInactive)
    except OSError as e:
        panic("Setting a timer to remove inactive peers failed: " & e.msg)

proc lockIP*(
    network: Network,
    ip: string,
    mask: uint8 = CLIENT_IP_LOCK
): Future[bool] {.forceCheck: [], async.} =
    #Acquire the IP lock.
    while true:
        if tryAcquire(network.ipLock):
            break

        try:
            await sleepAsync(10)
        except Exception as e:
            panic("Failed to complete an async sleep: " & e.msg)

    if not network.masks.hasKey(ip):
        network.masks[ip] = mask
        result = true
    else:
        var currMask: uint8
        try:
            currMask = network.masks[ip]
        except KeyError as e:
            panic("Couldn't get an IP's mask despite confirming the key exists: " & e.msg)

        #If we're currently attempting a client connection, or attempting to handle this server connection, set the result to false.
        if (
            ((currMask and CLIENT_IP_LOCK) == CLIENT_IP_LOCK) or
            ((currMask and mask) == mask)
        ):
            result = false
        else:
            #Add the mask and set the result to true.
            network.masks[ip] = currMask or mask
            result = true

    #Release the IP lock.
    release(network.ipLock)

proc unlockIP*(
    network: Network,
    ip: string,
    mask: uint8 = CLIENT_IP_LOCK
) {.forceCheck: [], async.} =
    #Acquire the IP lock.
    while true:
        if tryAcquire(network.ipLock):
            break

        try:
            await sleepAsync(10)
        except Exception as e:
            panic("Failed to complete an async sleep: " & e.msg)

    #Remove the bitmask.
    var mask: uint8
    try:
        mask = network.masks[ip] and (not mask)
    except KeyError as e:
        panic("Attempted to unlock an IP that was never locked: " & e.msg)

    #Delete the mask entirely if it's no longer used.
    if mask == 0:
        network.masks.del(ip)
    else:
        network.masks[ip] = mask

    #Release the IP lock.
    release(network.ipLock)

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
