#Finals lib.
import finals

#Socket standard lib.
import asyncnet

#Client object.
finalsd:
    type
        HandshakeState* = enum
            Error = 0,
            Complete = 1,
            MissingBlocks = 2

        ClientState* = enum
            Shaking = 0,
            ShakingAndSyncing = 1,
            Syncing = 2,
            Ready = 3

        Client* = ref object of RootObj
            #IP.
            ip* {.final.}: string
            #Port.
            port* {.final.}: uint
            #ID.
            id* {.final.}: uint
            #State.
            state*: ClientState
            #Socket.
            socket* {.final.}: AsyncSocket

#Constructor.
func newClient*(ip: string, port: uint, id: uint, socket: AsyncSocket): Client {.raises: [].} =
    result = Client(
        ip: ip,
        port: port,
        id: id,
        state: ClientState.Shaking,
        socket: socket
    )
    result.ffinalizeIP()
    result.ffinalizePort()
    result.ffinalizeID()
    result.ffinalizeSocket()
