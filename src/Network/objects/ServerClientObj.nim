#SetOnce lib.
import SetOnce

#Socket standard lib.
import asyncnet

#ServerClient object.
type ServerClient* = ref object of RootObj
    #ID.
    id*: SetOnce[int]
    #Socket.
    socket*: SetOnce[AsyncSocket]

#Constructor.
proc newServerClient*(id: int, socket: AsyncSocket): ServerClient {.raises: [ValueError].} =
    result = ServerClient()
    result.id.value = id
    result.socket.value = socket

#Converter so we don't always have to .getSocket(), but instead can directly use .recvLine()
converter ServerClientToAsyncSocket*(sc: ServerClient): AsyncSocket {.raises: [].} =
    sc.socket
