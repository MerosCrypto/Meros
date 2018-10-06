#Errors lib.
import ../../lib/Errors

#Client object.
import ClientObj

#Finals lib.
import finals

#sequtils standard lib.
import sequtils

#Networking standard lib.
import asyncnet

#Clients object.
finalsd:
    type Clients* = ref object of RootObj
        total*: int
        clients*: seq[Client]

#Constructor.
func newClients*(): Clients {.raises: [].} =
    Clients(
        total: 0,
        clients: newSeq[Client]()
    )

#Getter.
func getClient*(clients: Clients, id: int): Client {.raises: [].} =
    for client in clients.clients:
        if client.id == id:
            return client

#Disconnect.
proc disconnect*(clients: Clients, id: int) {.raises: [SocketError].} =
    for i, client in clients.clients:
        if client.id == id:
            try:
                client.close()
            except:
                raise newException(SocketError, "Could not disconnect a Client.")
            clients.clients.delete(i)

#Disconnects every client.
proc shutdown*(clients: Clients) {.raises: [SocketError].} =
    for i, client in clients.clients:
        try:
            client.close()
        except:
            raise newException(SocketError, "Could not disconnect a Client.")
        clients.clients.delete(i)
