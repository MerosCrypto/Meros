#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Locks standard lib.
import locks

#Table standard lib.
import tables

#Random standard lib.
import random

#Networking standard lib.
import asyncnet

#Service bytes.
const SERVER_SERVICE*: uint8 = 0b10000000

#Peer object.
type Peer* = ref object
    #ID.
    id*: int

    #IP.
    ip*: string
    #Server who can accept connections.
    server*: bool
    #Port of their server.
    port*: int

    #Time of their last message.
    last*: uint32

    #Sync Lock.
    syncLock*: Lock
    #Pending sync requests.
    requests*: seq[int]

    #Sockets.
    live*: AsyncSocket
    sync*: AsyncSocket

#Constructor.
func newPeer*(
    ip: string,
): Peer {.forceCheck: [].} =
    result = Peer(
        ip: ip,
        last: getTime()
    )
    initLock(result.syncLock)

#Check if a Peer is closed.
func isClosed*(
    peer: Peer
): bool {.inline, forceCheck: [].} =
    (
        peer.live.isNil or peer.live.isClosed()
    ) and (
        peer.sync.isNil or peer.sync.isClosed()
    )

#Close a Peer.
proc close*(
    peer: Peer
) {.forceCheck: [].} =
    try:
        if not peer.live.isNil:
            peer.live.close()
    except Exception:
        discard

    try:
        if not peer.sync.isNil:
            peer.sync.close()
    except Exception:
        discard

#Get random peers which meet criteria.
#Helper function used in a few places.
proc getPeers*(
    peers: TableRef[int, Peer],
    reqArg: int,
    skip: int = 1,
    live: bool = false,
    server: bool = false
): seq[Peer] {.forceCheck: [].} =
    var
        req: int = reqArg
        peersLeft: int = peers.len
    for peer in peers.values():
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
            if live and (peer.live.isNil or peer.live.isClosed):
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
