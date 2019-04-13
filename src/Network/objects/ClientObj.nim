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
            Error = 0,
            MissingBlocks = 1,
            Complete = 2

        ClientState* = enum
            Syncing = 0,
            Ready = 1

        Client* = ref object of RootObj
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
): Client {.raises: [].} =
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
func isClosed*(client: Client): bool {.raises: [].} =
    client.socket.isClosed()

#Close a Client.
proc close*(client: Client) {.raises: [SocketError].} =
    try:
        client.socket.close()
    except:
        raise newException(SocketError, "Couldn't close the socket.")
