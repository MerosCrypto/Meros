#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Socket standard lib.
import asyncnet

#Peer object.
type Peer* = ref object
    #IP.
    ip*: string
    #Server who can accept connections.
    server*: bool
    #Port of their server.
    port*: int

    #ID.
    id*: int
    #Time of their last message.
    last*: uint32

    #Sockets.
    live*: AsyncSocket
    sync*: AsyncSocket

#Constructor.
func newPeer*(
    ip: string,
    id: int,
    socket: AsyncSocket
): Peer {.inline, forceCheck: [].} =
    Peer(
        ip: ip,
        server: false,
        port: -1,

        id: id,
        syncLevels: 0,
        pendingSyncRequest: false,
        remoteSync: false,
        syncedSameTime: false,
        last: 0,

        socket: socket
    )

#Check if a Peer is closed.
func isClosed*(
    peer: Peer
): bool {.inline, forceCheck: [].} =
    peer.socket.isClosed()

#Close a Peer.
proc close*(
    peer: Peer
) {.forceCheck: [].} =
    try:
        peer.socket.close()
    except Exception:
        discard
