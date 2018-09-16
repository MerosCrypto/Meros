#SetOnce lib.
import SetOnce

#Socket standard lib.
import asyncnet

#Client object.
type Client* = ref object of RootObj
    #ID.
    id*: SetOnce[int]
    #Socket.
    socket*: SetOnce[AsyncSocket]

#Constructor.
proc newClient*(id: int, socket: AsyncSocket): Client {.raises: [ValueError].} =
    result = Client()
    result.id.value = id
    result.socket.value = socket

#Converter so we don't always have to .socket, but instead can directly use .recv().
converter toSocket*(sc: Client): AsyncSocket {.raises: [].} =
    sc.socket
