#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Socket standard lib.
import asyncnet

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

    #Sockets.
    live*: AsyncSocket
    sync*: AsyncSocket

#Constructor.
func newPeer*(
    ip: string,
    server: bool,
    port: int
): Peer {.inline, forceCheck: [].} =
    Peer(
        ip: ip,
        server: server,
        port: port,

        last: getTime()
    )

#Check if a Peer is closed.
func isClosed*(
    peer: Peer
): bool {.inline, forceCheck: [].} =
    (
        (not peer.live.isNil) and (not peer.live.isClosed())
    ) or (
        (not peer.sync.isNil) and (not peer.sync.isClosed())
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
