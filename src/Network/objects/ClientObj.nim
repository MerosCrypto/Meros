#Errors lib.
import ../../lib/Errors

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

        Client* = object
            #IP.
            ip* {.final.}: string
            #Port.
            port* {.final.}: int
            #ID.
            id* {.final.}: int
            #Our state.
            ourState*: ClientState
            #Their state.
            theirState*: ClientState
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
        id: id,
        ourState: ClientState.Ready,
        theirState: ClientState.Ready,
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
