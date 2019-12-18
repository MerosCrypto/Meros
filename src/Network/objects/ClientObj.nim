#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Finals lib.
import finals

#Socket standard lib.
import asyncnet

#Client object.
finalsd:
    type Client* = ref object
        #IP.
        ip* {.final.}: string
        #Port.
        port* {.final.}: int
        #Server who can accept connections.
        server* {.final.}: bool

        #ID.
        id* {.final.}: int
        #Are we syncing? Every sync process adds one, removing one as it terminates.
        syncLevels*: int
        #Do we have a pending sync request?
        pendingSyncRequest*: bool
        #Whether or not the client is syncing.
        remoteSync*: bool
        #Time of their last message.
        last*: uint32

        #Socket.
        socket* {.final.}: AsyncSocket

#Constructor.
func newClient*(
    ip: string,
    port: int,
    id: int,
    socket: AsyncSocket
): Client {.forceCheck: [].} =
    result = Client(
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
    result.ffinalizeIP()
    result.ffinalizePort()
    result.ffinalizeID()
    result.ffinalizeSocket()


#Check if a Client is closed.
func isClosed*(
    client: Client
): bool {.forceCheck: [].} =
    client.socket.isClosed()

#Close a Client.
proc close*(client: Client) {.forceCheck: [].} =
    try:
        client.socket.close()
    except Exception:
        discard
