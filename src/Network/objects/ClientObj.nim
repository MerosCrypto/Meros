#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Socket standard lib.
import asyncnet

#Client object.
type Client* = ref object
    #IP.
    ip*: string
    #Server who can accept connections.
    server*: bool
    #Port of their server.
    port*: int

    #ID.
    id*: int
    #Are we syncing? Every sync process adds one, removing one as it terminates.
    syncLevels*: int
    #Do we have a pending sync request?
    pendingSyncRequest*: bool
    #Whether or not the client is syncing.
    remoteSync*: bool
    #Whether or not they started syncing when we started syncing.
    syncedSameTime*: bool
    #Time of their last message.
    last*: uint32

    #Socket.
    socket*: AsyncSocket

#Constructor.
func newClient*(
    ip: string,
    id: int,
    socket: AsyncSocket
): Client {.inline, forceCheck: [].} =
    Client(
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

#Check if a Client is closed.
func isClosed*(
    client: Client
): bool {.inline, forceCheck: [].} =
    client.socket.isClosed()

#Close a Client.
proc close*(
    client: Client
) {.forceCheck: [].} =
    try:
        client.socket.close()
    except Exception:
        discard
