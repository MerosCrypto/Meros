#Client object.
import ClientObj

#SetOnce lib.
import SetOnce

#sequtils standard lib.
import sequtils

#Networking standard lib.
import asyncnet

#Clients object.
type Clients* = ref object of RootObj
    total*: int
    clients*: seq[Client]

#Constructor.
proc newClients*(): Clients {.raises: [].} =
    Clients(
        total: 0,
        clients: newSeq[Client](5)
    )

#Getter.
proc getClient*(clients: Clients, id: int): Client {.raises: [].} =
    for client in clients.clients:
        if client.id == id:
            return client

#Disconnect.
proc disconnect*(clients: Clients, id: int) {.raises: [Exception].} =
    for i, client in clients.clients:
        if client.id == id:
            client.close()
            clients.clients.delete(i)
