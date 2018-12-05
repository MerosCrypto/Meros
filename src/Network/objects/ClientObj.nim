#Finals lib.
import finals

#Socket standard lib.
import asyncnet

#Client object.
finalsd:
    type Client* = ref object of RootObj
        #IP.
        ip* {.final.}: string
        #Port.
        port* {.final.}: uint
        #ID.
        id* {.final.}: uint
        #Shaking.
        shaking*: bool
        #Syncing.
        syncing*: bool
        #Socket.
        socket* {.final.}: AsyncSocket

#Constructor.
func newClient*(ip: string, port: uint, id: uint, socket: AsyncSocket): Client {.raises: [].} =
    result = Client(
        ip: ip,
        port: port,
        id: id,
        shaking: true,
        syncing: false,
        socket: socket
    )
    result.ffinalizeID()
    result.ffinalizeSocket()

#Converter so we don't always have to .socket, but instead can directly use .recv().
converter toSocket*(client: Client): AsyncSocket {.raises: [].} =
    client.socket
