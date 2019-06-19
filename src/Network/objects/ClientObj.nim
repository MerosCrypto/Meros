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
    type
        HandshakeState* = enum
            MissingBlocks = 0,
            Complete = 1

        ClientState* = enum
            Syncing = 0,
            Ready = 1

        Client* = ref object
            #IP.
            ip* {.final.}: string
            #Port.
            port* {.final.}: int
            #Server who can accept connections.
            server* {.final.}: bool
            #ID.
            id* {.final.}: int
            #Our state.
            ourState*: ClientState
            #Their state.
            theirState*: ClientState
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
        ourState: ClientState.Ready,
        theirState: ClientState.Ready,
        socket: socket,
        last: 0
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
