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
    #Port.
    port*: int
    #Server who can accept connections.
    server*: bool

    #ID.
    id*: int
    #Are we syncing? Every sync process adds one, removing one as it terminates.
    syncLevels*: int
    #Do we have a pending sync request?
    pendingSyncRequest*: bool
    #Whether or not the client is syncing.
    remoteSync*: bool
    #Time of their last message.
    last*: uint32

    #Socket.
    socket*: AsyncSocket

#Constructor.
func newClient*(
    ip: string,
    port: int,
    id: int,
    socket: AsyncSocket
): Client {.inline, forceCheck: [].} =
    Client(
        ip: ip,
        port: port,
        server: false,

        id: id,
        syncLevels: 0,
        pendingSyncRequest: false,
        remoteSync: false,
        last: 0,

        socket: socket
    )

#Check if a Client is closed.
func isClosed*(
    client: Client
): bool {.inline, forceCheck: [].} =
    client.socket.isClosed()

#Close a Client.
proc close*(client: Client) {.forceCheck: [].} =
    try:
        client.socket.close()
    except Exception:
        discard
