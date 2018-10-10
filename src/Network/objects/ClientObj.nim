#Finals lib.
import finals

#Socket standard lib.
import asyncnet

#Client object.
finalsd:
    type Client* = ref object of RootObj
        #ID.
        id* {.final.}: uint
        #Socket.
        socket* {.final.}: AsyncSocket

#Constructor.
func newClient*(id: uint, socket: AsyncSocket): Client {.raises: [].} =
    result = Client(
        id: id,
        socket: socket
    )

#Converter so we don't always have to .socket, but instead can directly use .recv().
converter toSocket*(client: Client): AsyncSocket {.raises: [].} =
    client.socket
