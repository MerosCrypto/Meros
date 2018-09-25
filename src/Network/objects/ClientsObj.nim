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
proc newClients*(): Clients {.raises: [].} =
    Clients(
        total: 0,
        clients: newSeq[Client]()
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
