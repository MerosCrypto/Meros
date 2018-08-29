#Socket lib.
import asyncnet

#ServerClient object.
type ServerClient* = ref object of RootObj
    #ID.
    id: int
    #Socket.
    socket: AsyncSocket

#Constructor.
proc newServerClient*(id: int, socket: AsyncSocket): ServerClient {.raises: [].} =
    ServerClient(
        id: id,
        socket: socket
    )

#Getter.
proc getID*(sc: ServerClient): int {.raises: [].} =
    sc.id

#Converter so we don't always have to .getSocket(), but instead can directly use .recvLine()
converter ServerClientToAsyncSocket*(sc: ServerClient): AsyncSocket {.raises: [].} =
    sc.socket
