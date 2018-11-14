#Errors lib.
import ../../lib/Errors

#Client object.
import ClientObj

#sequtils standard lib.
import sequtils

#Networking standard lib.
import asyncnet

#Clients object.
type Clients* = ref object of RootObj
    total*: uint
    clients*: seq[Client]

#Constructor.
func newClients*(): Clients {.raises: [].} =
    Clients(
        total: 1,
        clients: newSeq[Client]()
    )

#Getter.
func getClient*(clients: Clients, id: uint): Client {.raises: [].} =
    for client in clients.clients:
        if client.id == id:
            return client

#Disconnect.
proc disconnect*(clients: Clients, id: uint) {.raises: [].} =
    for i, client in clients.clients:
        if client.id == id:
            try:
                client.close()
            except:
                #If we can't close the Client, we should still delete it from Clients.
                discard
            clients.clients.delete(i)

#Disconnects every client.
proc shutdown*(clients: Clients) {.raises: [SocketError].} =
    for i, client in clients.clients:
        try:
            client.close()
        except:
            raise newException(SocketError, "Could not disconnect a Client.")
        clients.clients.delete(i)
